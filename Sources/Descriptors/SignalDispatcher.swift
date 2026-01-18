import Glibc
import Foundation
import FreeBSDKit

public struct SignalDispatcher<KQ: KqueueDescriptor & ~Copyable>: ~Copyable {

    private let kq: KQ
    private var pending: [BSDSignal] = []
    private var handlers: [BSDSignal: [@Sendable () -> Void]] = [:]

    // MARK: Initialization

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

    // MARK: Handler Registration

    public mutating func on(
        _ signal: BSDSignal,
        perform handler: @escaping @Sendable () -> Void
    ) {
        handlers[signal, default: []].append(handler)
    }

    // MARK: Dispatch Loop

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

    // MARK: Drain kqueue (internal)

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
                            throw POSIXError(.init(rawValue: errno)!)
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
