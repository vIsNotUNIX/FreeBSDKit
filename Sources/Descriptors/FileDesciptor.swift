/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
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
        precondition(count >= 0)

        var buffer = Data(count: count)

        let (n, err): (Int, Int32) = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr -> (Int, Int32) in
                while true {
                    let r = Glibc.pread(fd, ptr.baseAddress, ptr.count, offset)
                    if r >= 0 { return (Int(r), 0) }
                    if errno == EINTR { continue }
                    return (-1, errno)
                }
            }
        }

        if n < 0 { try BSDError.throwErrno(err) }

        buffer.removeSubrange(n..<buffer.count)
        return buffer
    }

    func pwrite(_ data: Data, offset: off_t) throws -> Int {
        let (n, err): (Int, Int32) = try self.unsafe { fd in
            data.withUnsafeBytes { ptr -> (Int, Int32) in
                while true {
                    let r = Glibc.pwrite(fd, ptr.baseAddress, ptr.count, offset)
                    if r >= 0 { return (Int(r), 0) }
                    if errno == EINTR { continue }
                    return (-1, errno)
                }
            }
        }

        if n < 0 { try BSDError.throwErrno(err) }
        return n
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
