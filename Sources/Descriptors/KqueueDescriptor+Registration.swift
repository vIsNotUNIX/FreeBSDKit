import Foundation
import FreeBSDKit
import Glibc

public extension KqueueDescriptor where Self: ~Copyable {
    func registerSignal(_ signal: BSDSignal) throws {
        guard signal.isCatchable else {
            throw POSIXError(.EINVAL)
        }

        let change = SwiftGlibc.kevent(
            ident: UInt(signal.rawValue),
            filter: Int16(EVFILT_SIGNAL),
            flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
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

    func unregisterSignal(_ signal: BSDSignal) throws {
        let change = SwiftGlibc.kevent(
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

    static func blockSignals(_ signals: [BSDSignal]) throws {
        var mask = sigset_t()
        sigemptyset(&mask)

        for sig in signals {
            sigaddset(&mask, sig.rawValue)
        }

        if pthread_sigmask(SIG_BLOCK, &mask, nil) != 0 {
            throw POSIXError(.init(rawValue: errno)!)
        }
    }

    /// Can't implement async stream here as Self: ~Copyable
    func nextSignal(maxEvents: Int = 8) async throws -> BSDSignal {
        try await withCheckedThrowingContinuation { cont in
            self.unsafe { fd in
                _ = Task<Void, Never> {
                    do {
                        var events = Array<kevent>(
                            repeating: SwiftGlibc.kevent(),
                            count: maxEvents
                        )

                        let count32 = events.withUnsafeMutableBufferPointer { evBuf in
                            _kevent_c(
                                fd,
                                nil,
                                0,
                                evBuf.baseAddress,
                                Int32(maxEvents),
                                nil
                            )
                        }

                        guard count32 >= 0 else {
                            throw POSIXError(.init(rawValue: errno)!)
                        }

                        let count = Int(count32)

                        for ev in events.prefix(count)
                            where ev.filter == Int16(EVFILT_SIGNAL)
                        {
                            if let sig = BSDSignal(rawValue: Int32(ev.ident)) {
                                cont.resume(returning: sig)
                                return
                            }
                        }

                        cont.resume(throwing: POSIXError(.EAGAIN))
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
                return
            }
        }
    }
}