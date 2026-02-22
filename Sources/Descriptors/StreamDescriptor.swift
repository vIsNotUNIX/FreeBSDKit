/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
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
    public static let noSignal   = SocketFlags(rawValue: MSG_NOSIGNAL)

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
        // Handle empty data up front to avoid nil baseAddress
        if data.isEmpty {
            return 0
        }
        return try self.unsafe { fd in
            let sent: Int = data.withUnsafeBytes { ptr in
                while true {
                    let result = Glibc.send(fd, ptr.baseAddress, ptr.count, flags.rawValue | MSG_NOSIGNAL)
                    if result == -1 && errno == EINTR { continue }
                    return Int(result)
                }
            }
            if sent < 0 {
                try BSDError.throwErrno(errno)
            }
            return sent
        }
    }

    func sendAll(_ data: Data, flags: SocketFlags = []) throws {
        // Handle empty data up front to avoid nil baseAddress
        if data.isEmpty {
            return
        }

        try self.unsafe { fd in
            try data.withUnsafeBytes { ptr in
                var offset = 0
                while offset < ptr.count {
                    let base = ptr.baseAddress! // Safe because data not empty
                    let n = Glibc.send(
                        fd,
                        base.advanced(by: offset),
                        ptr.count - offset,
                        flags.rawValue | MSG_NOSIGNAL
                    )

                    if n == -1 {
                        if errno == EINTR { continue }
                        try BSDError.throwErrno(errno)
                    }

                    if n == 0 {
                        // No forward progress => avoid infinite loop
                        throw POSIXError(.EIO)
                    }

                    offset += n
                }
            }
        }
    }

    func recv(maxBytes: Int, flags: SocketFlags = []) throws -> RecvResult {
        guard maxBytes > 0 else { throw POSIXError(.EINVAL) }

        var buffer = Data(count: maxBytes)

        let n: Int = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr in
                while true {
                    let result = Glibc.recv(fd, ptr.baseAddress, ptr.count, flags.rawValue)
                    if result == -1 && errno == EINTR { continue }
                    return Int(result)
                }
            }
        }

        if n < 0 {
            try BSDError.throwErrno(errno)
        }

        if n == 0 {
            return .eof
        }

        buffer.removeSubrange(n..<buffer.count)
        return .data(buffer)
    }

    func recvExact(_ count: Int, flags: SocketFlags = []) throws -> Data {
        guard count >= 0 else {
            throw POSIXError(.EINVAL)
        }

        if count == 0 {
            return Data()
        }

        var result = Data()
        result.reserveCapacity(count)

        while result.count < count {
            switch try recv(maxBytes: count - result.count, flags: flags) {
            case .eof:
                // Unexpected EOF before reading all requested bytes
                throw POSIXError(.EIO)
            case .data(let chunk):
                result.append(chunk)
            }
        }
        return result
    }
}