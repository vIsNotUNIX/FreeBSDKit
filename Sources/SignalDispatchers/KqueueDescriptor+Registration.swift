/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import Descriptors
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
           throw BSDErrno.throwErrno(errno)
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
                           throw BSDErrno.throwErrno(errno)
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