/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - Read Result

/// Result of a read operation.
public enum ReadResult {
    case data(Data)
    case eof
}

// MARK: - Descriptor Capabilities

public protocol ReadableDescriptor: Descriptor, ~Copyable {
    func read(maxBytes: Int) throws -> ReadResult
    func readExact(_ count: Int) throws -> Data
}

public protocol WritableDescriptor: Descriptor, ~Copyable {
    func writeOnce(_ data: Data) throws -> Int
    func writeAll(_ data: Data) throws
}

public typealias ReadWriteDescriptor = ReadableDescriptor & WritableDescriptor

public extension ReadableDescriptor where Self: ~Copyable {

    func read(maxBytes: Int) throws -> ReadResult {
        precondition(maxBytes > 0, "maxBytes must be greater than 0")

        var buffer = Data(count: maxBytes)

        let n: Int = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr in
                while true {
                    let r = Glibc.read(fd, ptr.baseAddress, ptr.count)
                    if r == -1 && errno == EINTR { continue }
                    return Int(r)
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

    func readExact(_ count: Int) throws -> Data {
        precondition(count >= 0, "count must be non-negative")

        if count == 0 {
            return Data()
        }

        var result = Data()
        result.reserveCapacity(count)

        while result.count < count {
            switch try read(maxBytes: count - result.count) {
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

public extension WritableDescriptor where Self: ~Copyable {

    func writeOnce(_ data: Data) throws -> Int {
        try self.unsafe { fd in
            let n: Int = data.withUnsafeBytes { ptr in
                while true {
                    let r = Glibc.write(fd, ptr.baseAddress, ptr.count)
                    if r == -1 && errno == EINTR { continue }
                    return Int(r)
                }
            }

            if n < 0 {
                try BSDError.throwErrno(errno)
            }

            return n
        }
    }

    func writeAll(_ data: Data) throws {
        // Handle empty data up front to avoid nil baseAddress
        if data.isEmpty {
            return
        }

        try self.unsafe { fd in
            try data.withUnsafeBytes { ptr in
                var offset = 0
                while offset < ptr.count {
                    let base = ptr.baseAddress! // Safe because data not empty
                    let n = Glibc.write(
                        fd,
                        base.advanced(by: offset),
                        ptr.count - offset
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
}
