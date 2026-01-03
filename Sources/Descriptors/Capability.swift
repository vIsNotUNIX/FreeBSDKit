import Capsicum
import CCapsicum
import Glibc

protocol Capability: Descriptor, ~Copyable {}

extension Capability {
        // MARK: — Limiting Rights

    /// Applies a set of capability rights to a given file descriptor.
    ///
    /// - Parameter fd: A file descriptor to limit.
    /// - Parameter rights: A `CapabilityRightSet` representing the rights to permit.
    /// - Returns: `true` if the rights were successfully applied; `false` on failure.
    public func limit(rights: CapabilityRightSet) -> Bool {
        var val = false
        var cRights = rights.asCapRightsT()
        unsafeBorrow { fd in
            val = ccapsicum_cap_limit(fd, &cRights) == 0
        }
        return val
    }

    /// Restricts the set of permitted ioctl commands for a file descriptor.
    ///
    /// - Parameter fd: The file descriptor to limit.
    /// - Parameter commands: A list of ioctl codes (`IoctlCommand`) to permit.
    /// - Throws: `CapsicumError` if the underlying call fails.
    public func limitIoctls(commands: [IoctlCommand]) throws {
        let values = commands.map { $0.rawValue }
        var result: Int32 = -2
        unsafeBorrow { fd in 
            result = values.withUnsafeBufferPointer { cmdArray in
                ccapsicum_limit_ioctls(fd, cmdArray.baseAddress, cmdArray.count)
            }
        }

        if result == -1 {
            let err = errno
            throw CapsicumError.errorFromErrno(err)
        }
    }

    /// Restricts the permitted `fcntl(2)` commands on a file descriptor.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor to restrict.
    ///   - rights: An OptionSet of allowed fcntl commands.
    /// - Throws: `CapsicumFcntlError` on failure.
    public func limitFcntls( rights: FcntlRights) throws {
        var result: Int32 = -2
        unsafeBorrow { fd in
            result = ccapsicum_limit_fcntls(fd, rights.rawValue)
        }
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw CapsicumFcntlError.invalidDescriptor
            case EINVAL:
                throw CapsicumFcntlError.invalidFlag
            case ENOTCAPABLE:
                throw CapsicumFcntlError.notCapable
            default:
                throw CapsicumFcntlError.system(errno: errno)
            }
        }
    }
    // MARK: — Querying Limits

    /// Fetches the set of currently allowed ioctl commands for a descriptor.
    ///
    /// - Parameter fd: The descriptor whose ioctl limits are being queried.
    /// - Parameter maxCount: A buffer size hint for how many commands to buffer.
    /// - Throws: `CapsicumIoctlError` for invalid descriptors, bad buffers,
    ///   insufficient buffer size, “all allowed” state, or other errno conditions.
    /// - Returns: An array of permitted `IoctlCommand` values.
    public func getIoctls(maxCount: Int = 32) throws -> [IoctlCommand] {
        var rawBuffer = [UInt](repeating: 0, count: maxCount)
        var result: Int = -1

        unsafeBorrow { fd in
            result = ccapsicum_get_ioctls(fd, &rawBuffer, rawBuffer.count)
        }
        
        if result < 0 {
            switch errno {
            case EBADF:
                throw CapsicumIoctlError.invalidDescriptor
            case EFAULT:
                throw CapsicumIoctlError.badBuffer
            default:
                throw CapsicumIoctlError.system(errno: errno)
            }
        }
        
        if result == CAP_IOCTLS_ALL {
            throw CapsicumIoctlError.allIoctlsAllowed
        }
        
        let count = Int(result)
        if count > rawBuffer.count {
            throw CapsicumIoctlError.insufficientBuffer(expected: count)
        }
        
        return rawBuffer.prefix(count).map { IoctlCommand(rawValue: $0) }
    }

    /// Retrieves the currently permitted `fcntl` rights mask on a descriptor.
    ///
    /// - Parameter fd: The file descriptor whose fcntl rights are being queried.
    /// - Returns: A `FcntlRights` bitmask describing the allowed commands, or `nil` if the query fails.
    public func getFcntls() -> FcntlRights? {
        var rawMask: UInt32 = 0
        var result: Int32 = -2
        unsafeBorrow { fd in
            result = ccapsicum_get_fcntls(fd, &rawMask)
        }

        guard result >= 0 else {
            return nil
        }
        return FcntlRights(rawValue: rawMask)
    }
}