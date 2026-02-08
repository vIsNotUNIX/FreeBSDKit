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

/// An OptionSet for socket flags that can be used in `recv`/`send` operations
public struct SocketFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let oob        = SocketFlags(rawValue: MSG_OOB)
    public static let peek       = SocketFlags(rawValue: MSG_PEEK)
    public static let waitAll    = SocketFlags(rawValue: MSG_WAITALL)
    public static let dontWait   = SocketFlags(rawValue: MSG_DONTWAIT)

    // Control-message–related (sendmsg / recvmsg)
    public static let cmsgCloExec = SocketFlags(rawValue: MSG_CMSG_CLOEXEC)
    public static let cmsgCloFork = SocketFlags(rawValue: MSG_CMSG_CLOFORK)
}

/// A generic stream descriptor (read/write)
/// Useful when you don't want to hand full socket semantics just send/recv.
public protocol StreamDescriptor: ReadWriteDescriptor, ~Copyable {

    /// Attempt a single send(2). May perform a partial write.
    func sendOnce(_ data: Data, flags: SocketFlags) throws -> Int

    /// Send the entire buffer or throw.
    func sendAll(_ data: Data, flags: SocketFlags) throws

    /// Receive up to `maxBytes`. EOF is reported explicitly.
    func recv(maxBytes: Int, flags: SocketFlags) throws -> RecvResult

    /// Receive exactly `count` bytes or throw on EOF / error.
    func recvExact(_ count: Int, flags: SocketFlags) throws -> Data
}

public enum RecvResult {
    case data(Data)
    case eof
}

public extension StreamDescriptor where Self: ~Copyable {

    func sendOnce(_ data: Data, flags: SocketFlags = []) throws -> Int {
        try self.unsafe { fd in
            let sent = data.withUnsafeBytes { ptr in
                Glibc.send(fd, ptr.baseAddress, ptr.count, flags.rawValue)
            }
            if sent == -1 {
                if errno == EINTR { return 0 }
                try BSDError.throwErrno(errno)
            }
            return sent
        }
    }

    func sendAll(_ data: Data, flags: SocketFlags = []) throws {
        try self.unsafe { fd in
            try data.withUnsafeBytes { ptr in
                var offset = 0
                while offset < ptr.count {
                    let n = Glibc.send(
                        fd,
                        ptr.baseAddress!.advanced(by: offset),
                        ptr.count - offset,
                        flags.rawValue
                    )
                    if n == -1 {
                        if errno == EINTR { continue }
                        try BSDError.throwErrno(errno)
                    }
                    offset += n
                }
            }
        }
    }

    func recv(maxBytes: Int, flags: SocketFlags = []) throws -> RecvResult {
        var buffer = Data(count: maxBytes)

        let n = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr in
                Glibc.recv(fd, ptr.baseAddress, ptr.count, flags.rawValue)
            }
        }

        if n == -1 {
            if errno == EINTR { return .data(Data()) }
            try BSDError.throwErrno(errno)
        }

        if n == 0 {
            return .eof
        }

        buffer.removeSubrange(n..<buffer.count)
        return .data(buffer)
    }

    func recvExact(_ count: Int, flags: SocketFlags = []) throws -> Data {
        var result = Data()
        result.reserveCapacity(count)

        while result.count < count {
            switch try recv(maxBytes: count - result.count, flags: flags) {
            case .eof:
                throw POSIXError(.ENOTCONN)
            case .data(let chunk):
                result.append(chunk)
            }
        }
        return result
    }
}