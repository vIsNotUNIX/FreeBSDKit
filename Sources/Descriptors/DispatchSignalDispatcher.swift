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
public final class DispatchSignalDispatcher {

    private var sources: [BSDSignal: DispatchSourceSignal] = [:]

    /// Create a dispatcher for the given signals.
    ///
    /// - Parameters:
    ///   - signals: BSD signals to observe (must be catchable)
    ///   - queue: Dispatch queue on which handlers will run
    ///
    /// - Throws: `EINVAL` if an uncatchable signal is supplied
    public init(
        signals: [BSDSignal],
        queue: DispatchQueue = .global()
    ) throws {

        // Validate signals early
        for sig in signals where !sig.isCatchable {
            throw POSIXError(.EINVAL)
        }

        var mask = sigset_t()
        sigemptyset(&mask)

        // Block signals so delivery occurs only via Dispatch
        for sig in signals {
            sigaddset(&mask, sig.rawValue)
        }

        pthread_sigmask(SIG_BLOCK, &mask, nil)

        for sig in signals {
            let source = DispatchSource.makeSignalSource(
                signal: sig.rawValue,
                queue: queue
            )

            // Handler attached later
            source.resume()
            sources[sig] = source
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
