import Glibc
import Foundation

/// A capability‑friendly event file descriptor.
/// Implements the Linux/FreeBSD eventfd(2) interface.
public protocol EventDescriptor: Descriptor, ~Copyable {
    /// Create an eventfd with an initial count and flags (usually 0 or O_NONBLOCK|O_CLOEXEC).
    static func eventfd(initValue: UInt64, flags: Int32) throws -> Self

    /// Increment the counter by `value`.
    func signal(_ value: UInt64) throws

    /// Decrement/consume the counter and return its old value.
    func waitEvent() throws -> UInt64
}

public extension EventDescriptor where Self: ~Copyable {

    static func eventfd(initValue: UInt64, flags: Int32) throws -> Self {
        // On FreeBSD 13+ and Linux this exists in libc.
        let fd = Glibc.eventfd(UInt32(initValue), flags)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        return Self(fd)
    }

    func signal(_ value: UInt64) throws {
        try self.unsafe { fd in
            var v = value
            let written = withUnsafePointer(to: &v) {
                Glibc.write(fd, $0, MemoryLayout<UInt64>.size)
            }
            guard written == MemoryLayout<UInt64>.size else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    func waitEvent() throws -> UInt64 {
        var result: UInt64 = 0
        try self.unsafe { fd in
            let readBytes = withUnsafeMutablePointer(to: &result) {
                Glibc.read(fd, $0, MemoryLayout<UInt64>.size)
            }
            guard readBytes == MemoryLayout<UInt64>.size else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
        return result
    }
}
