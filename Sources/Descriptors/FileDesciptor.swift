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

public protocol FileDescriptor: ReadWriteDescriptor, ~Copyable {
    func seek(offset: off_t, whence: Int32) throws -> off_t
    func pread(count: Int, offset: off_t) throws -> Data
    func pwrite(_ data: Data, offset: off_t) throws -> Int
    func truncate(to length: off_t) throws
    func sync() throws
}

public extension FileDescriptor where Self: ~Copyable {

    func seek(offset: off_t, whence: Int32) throws -> off_t {
        try self.unsafe { fd in
            while true {
                let pos = Glibc.lseek(fd, offset, whence)
                if pos != -1 { return pos }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }

    func pread(count: Int, offset: off_t) throws -> Data {
        var buffer = Data(count: count)

        let n = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr in
                while true {
                    let r = Glibc.pread(fd, ptr.baseAddress, ptr.count, offset)
                    if r != -1 { return r }
                    if errno == EINTR { continue }
                    return -1
                }
            }
        }

        if n == -1 {
            try BSDError.throwErrno(errno)
        }

        buffer.removeSubrange(n..<buffer.count)
        return buffer
    }

    func pwrite(_ data: Data, offset: off_t) throws -> Int {
        try self.unsafe { fd in
            let n = data.withUnsafeBytes { ptr in
                while true {
                    let r = Glibc.pwrite(fd, ptr.baseAddress, ptr.count, offset)
                    if r != -1 { return r }
                    if errno == EINTR { continue }
                    return -1
                }
            }

            if n == -1 {
                try BSDError.throwErrno(errno)
            }

            return n
        }
    }

    func truncate(to length: off_t) throws {
        try self.unsafe { fd in
            while true {
                let r = Glibc.ftruncate(fd, length)
                if r == 0 { return }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }

    func sync() throws {
        try self.unsafe { fd in
            while true {
                let r = Glibc.fsync(fd)
                if r == 0 { return }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }
}
