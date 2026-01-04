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

import Capsicum
import CCapsicum
import Glibc
import FreeBSDKit

/// `Capability` inherits from `Descriptor`, meaning it represents a resource
/// with a raw `Int32` descriptor that can be closed and managed safely.
///
/// Conforming types indicate that the resource represents a **capability** in the
/// system — that is, a controlled access token to perform operations, rather than
/// just a raw descriptor. This is useful for enforcing capability-based security
/// patterns in your code.
///
/// Typically, types conforming to `Capability` are more restrictive or specialized
/// descriptors (e.g., `FileDescriptor`, `SocketDescriptor`, `KqueueDescriptor`),
/// providing safe operations in addition to the universal `close()` method.
public protocol Capability: Descriptor, ~Copyable {}

extension Capability {

    /// Applies a set of capability rights to a given file descriptor.
    ///
    /// - Parameter rights: A `CapabilityRightSet` representing the rights to permit.
    /// - Returns: `true` if the rights were successfully applied; `false` on failure.
    public func limit(rights: CapabilityRightSet) -> Bool {
        var mutableRights: cap_rights_t = cap_rights_t()
        rights.unsafe { borrowedRights in
            mutableRights = borrowedRights
        }

        return self.unsafe { fd in
            return ccapsicum_cap_limit(fd, &mutableRights) == 0
        }
    }

    /// Restricts a stream (file descriptor) according to the specified options.
    ///
    /// - Parameters:
    /// - options: Options specifying which operations are allowed (`StreamLimitOptions`).
    /// - Throws: `CapsicumError` if the underlying call fails.
    public func limitStream(options: StreamLimitOptions) throws {
        let result = self.unsafe { fd in 
            caph_limit_stream(fd, options.rawValue)
        }
        guard  result == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts the set of permitted ioctl commands for a file descriptor.
    ///
    /// - Parameter commands: A list of ioctl codes (`IoctlCommand`) to permit.
    /// - Throws: `CapsicumError` if the underlying call fails.
    public func limitIoctls(commands: [IoctlCommand]) throws {
        let values = commands.map { $0.rawValue }

        let result = self.unsafe { fd in
            values.withUnsafeBufferPointer { cmdArray in
                ccapsicum_limit_ioctls(fd, cmdArray.baseAddress, cmdArray.count)
            }
        }

        guard result != -1 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts the permitted `fcntl(2)` commands on a file descriptor.
    ///
    /// - Parameters:
    ///   - rights: An OptionSet of allowed fcntl commands.
    ///   - Throws: `CapsicumFcntlError` on failure.
    public func limitFcntls(rights: FcntlRights) throws {
        let result: Int32 = self.unsafe { fd in
            ccapsicum_limit_fcntls(fd, rights.rawValue)
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

    /// Fetches the set of currently allowed ioctl commands for a descriptor.
    ///
    /// - Parameter maxCount: A buffer size hint for how many commands to buffer.
    /// - Throws: `CapsicumIoctlError`.
    /// - Returns: An array of permitted `IoctlCommand` values.
    public func getIoctls(maxCount: Int = 32) throws -> [IoctlCommand] {
        var rawBuffer = [UInt](repeating: 0, count: maxCount)
        var result: Int = -1

        // Step 1: borrow the descriptor
        self.unsafe { fd in
            // Step 2: safely access the array memory
            rawBuffer.withUnsafeMutableBufferPointer { bufPtr in
                // C function returns Int32
                result = ccapsicum_get_ioctls(fd, bufPtr.baseAddress, bufPtr.count)
            }
        }

        // Step 3: handle errors
        guard result >= 0 else {
            switch errno {
            case EBADF:   throw CapsicumIoctlError.invalidDescriptor
            case EFAULT:  throw CapsicumIoctlError.badBuffer
            default:      throw CapsicumIoctlError.system(errno: errno)
            }
        }

        guard result != CAP_IOCTLS_ALL else {
            throw CapsicumIoctlError.allIoctlsAllowed
        }

        let count = Int(result)
        guard count <= rawBuffer.count else {
            throw CapsicumIoctlError.insufficientBuffer(expected: count)
        }

        return rawBuffer.prefix(count).map { IoctlCommand(rawValue: $0) }
    }

    /// Retrieves the currently permitted `fcntl` rights mask on a descriptor.
    ///
    /// - Returns: A `FcntlRights` bitmask describing the allowed commands, or `nil` if the query fails.
    public func getFcntls() -> FcntlRights? {
        var rawMask: UInt32 = 0

        let result: Int32 = self.unsafe { fd in
            ccapsicum_get_fcntls(fd, &rawMask)
        }

        guard result >= 0 else {
            return nil
        }

        return FcntlRights(rawValue: rawMask)
    }
}