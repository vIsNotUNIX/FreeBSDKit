/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Dispatch
import Foundation
import FreeBSDKit
import Glibc

/// A kqueue-based signal dispatcher.
///
/// - Signals are delivered via kqueue EVFILT_SIGNAL
/// - Signal counts are preserved (via ev.data)
/// - Intended for precise, kernel-accurate signal delivery
///
/// ## Threading Requirements
/// **IMPORTANT**: `pthread_sigmask` is thread-local. For signals to be handled
/// exclusively through this API, you must either:
/// 1. Create this dispatcher before spawning any threads (so they inherit the mask), or
/// 2. Ensure all threads block the same signals via `blockSignals()`, or
/// 3. Dedicate a single thread to signal handling
///
/// If other threads have unblocked signals, they will receive signals normally,
/// bypassing this dispatcher.
///
/// ## Concurrency
/// This is an actor, so all methods are automatically isolated. You can safely
/// call `on()` from any task/thread, including while `run()` is executing.
public actor KqueueSignalDispatcher {

    private let ownedFD: Int32
    private var pending: [BSDSignal] = []
    private var handlers: [BSDSignal: [@Sendable () -> Void]] = [:]
    private var isRunning = false

    /// Shared queue for blocking kevent calls to avoid blocking cooperative thread pool
    /// Concurrent to allow independent signal dispatchers to wait simultaneously
    private static let blockingQueue = DispatchQueue(
        label: "com.freebsdkit.signal.kqueue.blocking",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Create a dispatcher for the given signals.
    ///
    /// - Parameters:
    ///   - kqueue: The kqueue descriptor to use (consumed and duplicated internally)
    ///   - signals: BSD signals to observe (must all be catchable)
    ///
    /// - Throws: `EINVAL` if any uncatchable signal is supplied
    ///
    /// - Important: Signals are blocked via `pthread_sigmask`, which is thread-local.
    ///   See type documentation for threading requirements.
    public init<KQ: KqueueDescriptor & ~Copyable>(
        kqueue: consuming KQ,
        signals: [BSDSignal]
    ) throws {
        // Reject uncatchable signals early
        for sig in signals where !sig.isCatchable {
            throw POSIXError(.EINVAL)
        }

        try KQ.blockSignals(signals)

        for sig in signals {
            try kqueue.registerSignal(sig)
        }

        // Duplicate kqueue fd once for lifetime-safe blocking waits
        // After this, we don't need the original kqueue anymore
        self.ownedFD = try kqueue.unsafe { fd in
            let newFD = Glibc.fcntl(fd, F_DUPFD_CLOEXEC, 0)
            guard newFD != -1 else {
                try BSDError.throwErrno(errno)
            }
            return Int32(newFD)
        }
    }

    deinit {
        _ = Glibc.close(ownedFD)
    }

    /// Register a handler for a signal.
    ///
    /// Multiple handlers can be registered for the same signal.
    /// All handlers will be called synchronously in registration order within
    /// the actor's context.
    ///
    /// - Important: Handlers should be fast and non-blocking. Slow handlers will
    ///   delay signal processing and block other actor operations. If you need to
    ///   perform significant work, dispatch it to another queue or Task from within
    ///   the handler.
    public func on(
        _ signal: BSDSignal,
        perform handler: @escaping @Sendable () -> Void
    ) {
        handlers[signal, default: []].append(handler)
    }

    /// Run the dispatch loop.
    ///
    /// This method never returns normally. It waits for signals and dispatches them
    /// to registered handlers. Handlers are called synchronously in the order
    /// they were registered, within the actor's isolation.
    ///
    /// - Parameter maxEvents: Maximum signals to retrieve per kevent call (must be > 0)
    ///
    /// - Note: **Cancellation**: Task cancellation is only observed after the blocked
    ///   kevent call returns (i.e., after a signal arrives or an error occurs). The
    ///   dispatcher cannot interrupt a blocked kevent syscall. If you need immediate
    ///   cancellation, consider using a timeout-based implementation or EVFILT_USER wakeup.
    public func run(maxEvents: Int = 8) async throws {
        guard maxEvents > 0 else {
            throw POSIXError(.EINVAL)
        }

        // Prevent multiple concurrent run() calls
        guard !isRunning else {
            throw POSIXError(.EBUSY)
        }
        isRunning = true
        defer { isRunning = false }

        while true {
            // Check for cancellation at the start of each iteration
            try Task.checkCancellation()

            if pending.isEmpty {
                let drained = try await drain(maxEvents: maxEvents)
                if drained.isEmpty {
                    continue
                }
                pending.append(contentsOf: drained)
            }

            let sig = pending.removeFirst()

            for handler in handlers[sig] ?? [] {
                handler()
            }
        }
    }

    private func drain(maxEvents: Int) async throws -> [BSDSignal] {
        try await withCheckedThrowingContinuation { continuation in
            Self.blockingQueue.async { [ownedFD] in
                var events = Array<kevent>(
                    repeating: Glibc.kevent(),
                    count: maxEvents
                )

                while true {
                    let (n, err): (Int32, Int32) = events.withUnsafeMutableBufferPointer { buf in
                        let r = _kevent_c(
                            ownedFD,
                            nil,
                            0,
                            buf.baseAddress,
                            Int32(maxEvents),
                            nil
                        )
                        return (r, r < 0 ? errno : 0)
                    }

                    if n >= 0 {
                        var result: [BSDSignal] = []

                        for ev in events.prefix(Int(n))
                            where ev.filter == Int16(EVFILT_SIGNAL)
                        {
                            if let sig = BSDSignal(rawValue: Int32(ev.ident)) {
                                let count = max(1, Int(ev.data))
                                result.append(contentsOf: repeatElement(sig, count: count))
                            }
                        }

                        // If no signal events (e.g., kqueue has other filters registered),
                        // keep waiting instead of returning empty array
                        if result.isEmpty { continue }

                        // Check for cancellation before returning signals
                        do {
                            try Task.checkCancellation()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    // Retry on interruption
                    if err == EINTR { continue }

                    do {
                        try BSDError.throwErrno(err)
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                }
            }
        }
    }
}