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

public enum CapsicumHelper {

    /// Apply basic capability rights to a raw descriptor.
    public static func limit(fd: Int32, rights: CapsicumRightSet) -> Bool {
        var mutable = rights.rawBSD
        return ccapsicum_cap_limit(fd, &mutable) == 0
    }

    /// Limit a stream according to options.
    public static func limitStream(fd: Int32, options: StreamLimitOptions) throws {
        let result = caph_limit_stream(fd, options.rawValue)
        guard result == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Limit ioctl commands on a descriptor.
    public static func limitIoctls(fd: Int32, commands: [IoctlCommand]) throws {
        let values = commands.map(\.rawValue)
        let res = values.withUnsafeBufferPointer { buffer in
            ccapsicum_limit_ioctls(fd, buffer.baseAddress, buffer.count)
        }
        guard res != -1 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Limit fcntl rights.
    public static func limitFcntls(fd: Int32, rights: FcntlRights) throws {
        let res = ccapsicum_limit_fcntls(fd, rights.rawValue)
        guard res == 0 else {
            switch errno {
            case EBADF:       throw CapsicumFcntlError.invalidDescriptor
            case EINVAL:      throw CapsicumFcntlError.invalidFlag
            case ENOTCAPABLE: throw CapsicumFcntlError.notCapable
            default:          throw CapsicumFcntlError.system(errno: errno)
            }
        }
    }
    /// Get ioctl limits.
    public static func getIoctls(fd: Int32, maxCount: Int = 32) throws -> [IoctlCommand] {
        var buffer = [UInt](repeating: 0, count: maxCount)
        var result: Int = -1

        buffer.withUnsafeMutableBufferPointer { ptr in
            result = ccapsicum_get_ioctls(fd, ptr.baseAddress, ptr.count)
        }

        guard result >= 0 else {
            switch errno {
            case EBADF:  throw CapsicumIoctlError.invalidDescriptor
            case EFAULT: throw CapsicumIoctlError.badBuffer
            default:     throw CapsicumIoctlError.system(errno: errno)
            }
        }
        guard result != CAP_IOCTLS_ALL else {
            throw CapsicumIoctlError.allIoctlsAllowed
        }

        return Array(buffer.prefix(Int(result))).map { IoctlCommand(rawValue: $0) }
    }
    /// Get fcntl rights.
    public static func getFcntls(fd: Int32) throws -> FcntlRights {
        var rawMask: UInt32 = 0
        let res = ccapsicum_get_fcntls(fd, &rawMask)
        guard res >= 0 else {
            throw CapsicumFcntlError.system(errno: errno)
        }
        return FcntlRights(rawValue: rawMask)
    }
}
