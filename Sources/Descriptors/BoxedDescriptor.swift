import Glibc
import Foundation
import FreeBSDKit

// TODO: Make this thread safe?
public final class BoxedDescriptor: Descriptor, @unchecked Sendable {
    public let kind: DescriptorKind
    private var fd: Int32

    public init(_ value: RAWBSD) {
        self.fd = value
        self.kind = .unknown
    }

    public init(kind: DescriptorKind, fd: Int32) {
        self.kind = kind
        self.fd = fd
    }

    deinit {
        if fd >= 0 {
            Glibc.close(fd)
        }
    }

    public func take() -> Int32 {
        let raw = fd
        fd = -1
        return raw
    }

    public func unsafe<R>(_ body: (Int32) throws -> R) rethrows -> R {
        try body(fd)
    }

    public func close() {
        if fd >= 0 {
            Glibc.close(fd)
            fd = -1
        }
    }
}