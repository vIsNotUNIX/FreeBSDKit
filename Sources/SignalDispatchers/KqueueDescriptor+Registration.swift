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

/// Shared queue for blocking kevent operations
/// Concurrent to allow multiple independent kqueue waits
private let kqueueBlockingQueue = DispatchQueue(
    label: "com.freebsdkit.kqueue.blocking",
    qos: .userInitiated,
    attributes: .concurrent
)

public extension KqueueDescriptor where Self: ~Copyable {
    /// Register a signal for kqueue monitoring via EVFILT_SIGNAL.
    ///
    /// - Parameter signal: The signal to monitor (must be catchable)
    /// - Throws: `EINVAL` if the signal is not catchable
    func registerSignal(_ signal: BSDSignal) throws {
        guard signal.isCatchable else {
            throw POSIXError(.EINVAL)
        }

        let change = Glibc.kevent(
            ident: UInt(signal.rawValue),
            filter: Int16(EVFILT_SIGNAL),
            flags: UInt16(EV_ADD | EV_ENABLE),
            fflags: 0,
            data: 0,
            udata: nil,
            ext: (0, 0, 0, 0)
        )

        _ = try self.kevent(
            changes: [change],
            maxEvents: 0,
            timeout: nil
        )
    }

    /// Unregister a signal from kqueue monitoring.
    ///
    /// - Parameter signal: The signal to stop monitoring
    func unregisterSignal(_ signal: BSDSignal) throws {
        let change = Glibc.kevent(
            ident: UInt(signal.rawValue),
            filter: Int16(EVFILT_SIGNAL),
            flags: UInt16(EV_DELETE),
            fflags: 0,
            data: 0,
            udata: nil,
            ext: (0, 0, 0, 0)
        )

        _ = try self.kevent(
            changes: [change],
            maxEvents: 0,
            timeout: nil
        )
    }

    /// Block signals from normal delivery using pthread_sigmask.
    ///
    /// - Parameter signals: Signals to block
    ///
    /// - Important: `pthread_sigmask` is thread-local. This only blocks signals
    ///   for the calling thread. To block signals process-wide:
    ///   1. Call this before creating any threads (they inherit the mask), or
    ///   2. Call this in each thread
    static func blockSignals(_ signals: [BSDSignal]) throws {
        var mask = sigset_t()
        sigemptyset(&mask)

        for sig in signals {
            guard sigaddset(&mask, sig.rawValue) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }

        let error = pthread_sigmask(SIG_BLOCK, &mask, nil)

        if error != 0 {
           try BSDError.throwErrno(error)
        }
    }

    /// Wait for and return the next signal received via this kqueue.
    ///
    /// This method blocks until a signal event is available, then returns it.
    /// If multiple signals arrive, only one is returned per call.
    ///
    /// - Parameter maxEvents: Maximum events to retrieve per kevent call (must be > 0)
    /// - Returns: The signal that was received
    ///
    /// - Important: **Single waiter recommended**. If multiple tasks call this method
    ///   concurrently on the same kqueue, they will compete for events. Whichever task
    ///   wakes first consumes the event; others remain blocked. For multi-handler
    ///   dispatch, use `KqueueSignalHandler` instead.
    ///
    /// - Note: If the kqueue has other (non-signal) events registered, they will
    ///   be silently ignored and the method will continue waiting for signals.
    /// - Note: **Cancellation**: Task cancellation is observed cooperatively after the
    ///   blocked kevent call returns. The method cannot interrupt a blocked kevent syscall.
    ///   If the task is cancelled when kevent returns, `CancellationError` is thrown.
    /// - Note: Cannot implement AsyncStream here because Self: ~Copyable
    func nextSignal(maxEvents: Int = 8) async throws -> BSDSignal {
        guard maxEvents > 0 else {
            throw POSIXError(.EINVAL)
        }

        // Duplicate the fd so the blocking work has an owned copy
        // with guaranteed lifetime independent of self's lifecycle.
        let ownedFD: Int32 = try self.unsafe { fd in
            let newFD = Glibc.fcntl(fd, F_DUPFD_CLOEXEC, 0)
            guard newFD != -1 else {
                try BSDError.throwErrno(errno)
            }
            return Int32(newFD)
        }

        return try await withCheckedThrowingContinuation { continuation in
            kqueueBlockingQueue.async {
                defer { _ = Glibc.close(ownedFD) }

                var events = Array<kevent>(
                    repeating: Glibc.kevent(),
                    count: maxEvents
                )

                while true {
                    let (n, err): (Int32, Int32) = events.withUnsafeMutableBufferPointer { evBuf in
                        let r = _kevent_c(
                            ownedFD,
                            nil,
                            0,
                            evBuf.baseAddress,
                            Int32(maxEvents),
                            nil
                        )
                        return (r, r < 0 ? errno : 0)
                    }

                    if n >= 0 {
                        for ev in events.prefix(Int(n))
                            where ev.filter == Int16(EVFILT_SIGNAL)
                        {
                            if let sig = BSDSignal(rawValue: Int32(ev.ident)) {
                                // Check for cancellation before returning
                                do {
                                    try Task.checkCancellation()
                                    continuation.resume(returning: sig)
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                                return
                            }
                        }
                        continue
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