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

import CCapsicum
import Glibc

/// A Swift interface to the FreeBSD Capsicum sandboxing API.
///
/// Capsicum is a capability and sandbox framework built into FreeBSD that
/// allows a process to restrict itself to a set of permitted operations
/// on file descriptors and in capability mode. After entering capability
/// mode, access to global system namespaces (like files by pathname)
/// is disabled and operations are restricted to those explicitly
/// permitted via rights limits.
public enum Capsicum {

    // MARK: — Capability Mode

    /// Enters *Capsicum capability mode* for the current process.
    ///
    /// Once in capability mode, the process cannot access global namespaces
    /// such as the file system by path or the PID namespace. Only operations
    /// on file descriptors with appropriate rights remain permitted.
    ///
    /// - Throws: `CapsicumError.capsicumUnsupported` if Capsicum is unavailable.
    public static func enter() throws {
        guard cap_enter() == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
    }

    /// Determines whether the current process is already in capability mode.
    ///
    /// - Returns: `true` if capability mode is enabled, `false` otherwise.
    /// - Throws: `CapsicumError.capsicumUnsupported` if Capsicum is unavailable.
    public static func status() throws -> Bool {
        var mode: UInt32 = 0
        guard cap_getmode(&mode) == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
        return mode == 1
    }
    
    // MARK: — Limiting Rights

    /// Applies a set of capability rights to a given file descriptor.
    ///
    /// - Parameter fd: A file descriptor to limit.
    /// - Parameter rights: A `CapabilityRightSet` representing the rights to permit.
    /// - Returns: `true` if the rights were successfully applied; `false` on failure.
    public static func limit(fd: Int32, rights: CapabilityRightSet) -> Bool {
        var cRights = rights.asCapRightsT()
        return ccapsicum_cap_limit(fd, &cRights) == 0
    }

    /// Restricts the set of permitted ioctl commands for a file descriptor.
    ///
    /// - Parameter fd: The file descriptor to limit.
    /// - Parameter commands: A list of ioctl codes (`IoctlCommand`) to permit.
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitIoctls(fd: Int32, commands: [IoctlCommand]) throws {
        let values = commands.map { $0.rawValue }

        let result = values.withUnsafeBufferPointer { cmdArray in
            ccapsicum_limit_ioctls(fd, cmdArray.baseAddress, cmdArray.count)
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
    public static func limitFcntls(fd: Int32, rights: FcntlRights) throws {
        let result = ccapsicum_limit_fcntls(fd, rights.rawValue)
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
    public static func getIoctls(fd: Int32, maxCount: Int = 32) throws -> [IoctlCommand] {
        var rawBuffer = [UInt](repeating: 0, count: maxCount)
        let result = ccapsicum_get_ioctls(fd, &rawBuffer, rawBuffer.count)
        
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
    public static func getFcntls(fd: Int32) -> FcntlRights? {
        var rawMask: UInt32 = 0
        let result = ccapsicum_get_fcntls(fd, &rawMask)
        guard result >= 0 else {
            return nil
        }
        return FcntlRights(rawValue: rawMask)
    }
}