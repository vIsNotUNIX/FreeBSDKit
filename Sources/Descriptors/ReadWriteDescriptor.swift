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
        var buffer = Data(count: maxBytes)

        let n = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr in
                while true {
                    let r = Glibc.read(fd, ptr.baseAddress, ptr.count)
                    if r == -1 && errno == EINTR { continue }
                    return r
                }
            }
        }

        if n == -1 {
            throw  BSDError.throwErrno(errno)
        }

        if n == 0 {
            return .eof
        }

        buffer.removeSubrange(n..<buffer.count)
        return .data(buffer)
    }

    func readExact(_ count: Int) throws -> Data {
        var result = Data()
        result.reserveCapacity(count)

        while result.count < count {
            switch try read(maxBytes: count - result.count) {
            case .eof:
                throw POSIXError(.ENOTCONN)
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
            let n = data.withUnsafeBytes { ptr in
                while true {
                    let r = Glibc.write(fd, ptr.baseAddress, ptr.count)
                    if r == -1 && errno == EINTR { continue }
                    return r
                }
            }

            if n == -1 {
                throw  BSDError.throwErrno(errno)
            }

            return n
        }
    }

    func writeAll(_ data: Data) throws {
        try self.unsafe { fd in
            try data.withUnsafeBytes { ptr in
                var offset = 0
                while offset < ptr.count {
                    let n = Glibc.write(
                        fd,
                        ptr.baseAddress!.advanced(by: offset),
                        ptr.count - offset
                    )
                    if n == -1 {
                        if errno == EINTR { continue }
                        throw  BSDError.throwErrno(errno)
                    }
                    offset += n
                }
            }
        }
    }
}
