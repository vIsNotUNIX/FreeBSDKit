import Glibc
import Descriptors
import FreeBSDKit

/// A capability for a kqueue descriptor.
public struct KqueueCapability: Capability, KqueueDescriptor, ~Copyable {
    public typealias RAWBSD = Int32
    private var fd: RAWBSD

    /// Create from a raw descriptor.
    public init(_ raw: RAWBSD) {
        self.fd = raw
    }

    deinit {
        if fd >= 0 {
            Glibc.close(fd)
        }
    }

    public consuming func close() {
        if fd >= 0 {
            Glibc.close(fd)
            fd = -1
        }
    }

    public consuming func take() -> RAWBSD {
        let raw = fd
        fd = -1
        return raw
    }

    public func unsafe<R>(_ block: (RAWBSD) throws -> R ) rethrows -> R where R: ~Copyable {
        return try block(fd)
    }
}
