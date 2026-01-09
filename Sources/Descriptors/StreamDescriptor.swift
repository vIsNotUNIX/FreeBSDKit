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

import Glibc
import Foundation
import FreeBSDKit

import Foundation

/// An OptionSet for socket flags that can be used in `recv`/`send` operations
public struct SocketFlags: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let oob = SocketFlags(rawValue: MSG_OOB)
    public static let peek = SocketFlags(rawValue: MSG_PEEK)
    public static let trunc = SocketFlags(rawValue: MSG_TRUNC)
    public static let waitAll = SocketFlags(rawValue: MSG_WAITALL)
    public static let dontWait = SocketFlags(rawValue: MSG_DONTWAIT)
    public static let cmsgCloExec = SocketFlags(rawValue: MSG_CMSG_CLOEXEC)
    public static let cmsgCloFork = SocketFlags(rawValue: MSG_CMSG_CLOFORK)
    public static let waitForOne = SocketFlags(rawValue: MSG_WAITFORONE)
}


/// A generic stream descriptor (read/write)
public protocol StreamDescriptor: ReadWriteDescriptor, ~Copyable {
    func send(_ data: Data, flags: SocketFlags) throws -> Int
    func recv(count: Int, flags: SocketFlags) throws -> Data
}

public extension StreamDescriptor where Self: ~Copyable {
    func send(_ data: Data, flags: SocketFlags = []) throws -> Int {
        return try self.unsafe { fd in
            let bytesSent = data.withUnsafeBytes { ptr in
                Glibc.send(fd, ptr.baseAddress, ptr.count, flags.rawValue)
            }
            if bytesSent == -1 { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
            return bytesSent
        }
    }

    func recv(count: Int, flags: SocketFlags = []) throws -> Data {
        var buffer = Data(count: count)
        let n = try self.unsafe { fd in
            let bytesRead = buffer.withUnsafeMutableBytes { ptr in
                Glibc.recv(fd, ptr.baseAddress, count, flags.rawValue)
            }
            if bytesRead == -1 { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
            return bytesRead
        }
        buffer.removeSubrange(n..<buffer.count)
        return buffer
    }
}