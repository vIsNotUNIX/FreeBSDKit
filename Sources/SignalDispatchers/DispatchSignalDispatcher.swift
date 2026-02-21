/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CSignal
import Dispatch
import Foundation
import FreeBSDKit
import Glibc

/// A libdispatch-backed signal dispatcher.
///
/// - Signals are delivered via DispatchSourceSignal
/// - Signals are coalesced by libdispatch
/// - Signal counts are not preserved
/// - Intended for convenience, not kernel-accurate delivery
///
/// ## Threading Requirements
/// **IMPORTANT**: `pthread_sigmask` is thread-local. For signals to be handled
/// exclusively through this API, you must either:
/// 1. Create this dispatcher before spawning any threads (so they inherit the mask), or
/// 2. Ensure all threads block the same signals explicitly, or
/// 3. Accept that only the thread that created the dispatcher has its signals blocked
///
/// If other threads have unblocked signals, they will receive signals normally,
/// bypassing this dispatcher.
///
/// ## Process-Global Side Effects
/// **IMPORTANT**: Signal dispositions set via `sigaction()` are process-global.
/// This dispatcher assumes exclusive management of dispositions for its signals.
/// Do not mix with other signal handler/disposition management for the same signals,
/// as this could cause the saved dispositions to become stale and restoration to
/// break other code's signal handling.
///
/// ## Usage
/// Unlike `KqueueSignalDispatcher`, this dispatcher does not require an explicit `run()` loop.
/// Handlers are automatically invoked by libdispatch when signals arrive.
public final class DispatchSignalDispatcher {

    private var sources: [BSDSignal: DispatchSourceSignal] = [:]
    private var savedActions: [BSDSignal: sigaction] = [:]

    /// Create a dispatcher for the given signals.
    ///
    /// - Parameters:
    ///   - signals: BSD signals to observe (must all be catchable)
    ///   - queue: Dispatch queue on which handlers will run
    ///
    /// - Throws: `EINVAL` if any uncatchable signal is supplied
    ///
    /// - Important: Signals are blocked via `pthread_sigmask`, which is thread-local.
    ///   See type documentation for threading requirements.
    public init(
        signals: [BSDSignal],
        queue: DispatchQueue = .global()
    ) throws {

        // Deduplicate signals to prevent multiple sources for same signal
        let uniqueSignals = Array(Set(signals))

        // Reject uncatchable signals early
        for sig in uniqueSignals where !sig.isCatchable {
            throw POSIXError(.EINVAL)
        }

        var mask = sigset_t()
        sigemptyset(&mask)

        // Block signals so delivery occurs only via Dispatch
        for sig in uniqueSignals {
            guard sigaddset(&mask, sig.rawValue) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }

        let rc = pthread_sigmask(SIG_BLOCK, &mask, nil)
        if rc != 0 {
            throw BSDError.fromErrno(rc)
        }

        // Set signal dispositions to SIG_IGN and save previous actions
        // This is necessary for DispatchSourceSignal to work correctly:
        // - pthread_sigmask only blocks thread delivery, not process disposition
        // - Without SIG_IGN, signals may still cause default actions (terminate/stop)
        // - DispatchSourceSignal expects signals to be ignored for proper monitoring
        for sig in uniqueSignals {
            var newAction = sigaction()
            var oldAction = sigaction()

            // Set handler to SIG_IGN using C helper (FreeBSD sigaction has a union)
            csignal_set_ignore(&newAction)

            guard csignal_action(sig.rawValue, &newAction, &oldAction) == 0 else {
                // Rollback any already-set actions
                for (prevSig, prevAction) in savedActions {
                    var restore = prevAction
                    _ = csignal_action(prevSig.rawValue, &restore, nil)
                }
                try BSDError.throwErrno(errno)
            }

            savedActions[sig] = oldAction

            let source = DispatchSource.makeSignalSource(
                signal: sig.rawValue,
                queue: queue
            )

            // Handler attached later
            source.resume()
            sources[sig] = source
        }
    }

    deinit {
        cancel()

        // Restore original signal actions
        for (sig, action) in savedActions {
            var restore = action
            _ = csignal_action(sig.rawValue, &restore, nil)
        }
    }

    /// Register (or replace) a handler for a signal.
    public func on(
        _ signal: BSDSignal,
        handler: @escaping @Sendable () -> Void
    ) {
        sources[signal]?.setEventHandler(handler: handler)
    }

    /// Cancel all signal sources and release resources.
    public func cancel() {
        for source in sources.values {
            source.cancel()
        }
        sources.removeAll()
    }
}
