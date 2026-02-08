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

public struct KqueueSignalDispatcher<KQ: KqueueDescriptor & ~Copyable>: ~Copyable {

    private let kq: KQ
    private var pending: [BSDSignal] = []
    private var handlers: [BSDSignal: [@Sendable () -> Void]] = [:]

    public init(
        kqueue: consuming KQ,
        signals: [BSDSignal]
    ) throws {
        self.kq = kqueue

        try KQ.blockSignals(signals)

        for sig in signals where sig.isCatchable {
            try kq.registerSignal(sig)
        }
    }

    /// Handler Registration
    public mutating func on(
        _ signal: BSDSignal,
        perform handler: @escaping @Sendable () -> Void
    ) {
        handlers[signal, default: []].append(handler)
    }

    /// Dispatch Loop. Never returns
    public mutating func run(maxEvents: Int = 8) async throws {
        while true {
            if pending.isEmpty {
                pending.append(contentsOf: try await drain(maxEvents: maxEvents))
            }

            let sig = pending.removeFirst()

            for handler in handlers[sig] ?? [] {
                handler()
            }
        }
    }

    private func drain(maxEvents: Int) async throws -> [BSDSignal] {
        try await withCheckedThrowingContinuation { cont in
            kq.unsafe { fd in
                _ = Task<Void, Never> {
                    do {
                        var events = Array<kevent>(
                            repeating: SwiftGlibc.kevent(),
                            count: maxEvents
                        )

                        let n32 = events.withUnsafeMutableBufferPointer { buf in
                            _kevent_c(
                                fd,
                                nil,
                                0,
                                buf.baseAddress,
                                Int32(maxEvents),
                                nil
                            )
                        }

                        guard n32 >= 0 else {
                           try BSDError.throwErrno(errno)
                        }

                        let n = Int(n32)
                        var result: [BSDSignal] = []

                        for ev in events.prefix(n)
                            where ev.filter == Int16(EVFILT_SIGNAL)
                        {
                            if let sig = BSDSignal(rawValue: Int32(ev.ident)) {
                                let count = max(1, Int(ev.data))
                                result.append(contentsOf: repeatElement(sig, count: count))
                            }
                        }

                        cont.resume(returning: result)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
                return ()
            }
        }
    }
}