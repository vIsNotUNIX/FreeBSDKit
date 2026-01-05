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
import Descriptors
import Foundation
import FreeBSDKit


// TODO: A seperate protocol should be used to describe file operations.
struct FileCapability: Capability, FileDescriptor, ~Copyable {
    public typealias RAWBSD = Int32
    private var fd: RAWBSD

    init(_ value: RAWBSD) {
        self.fd = value
    }

    deinit {
        if fd >= 0 {
            Glibc.close(fd)
        }
    }

    consuming func close() {
        if fd >= 0 {
            Glibc.close(fd)
            fd = -1
        }
    }

    consuming func take() -> RAWBSD {
        let rawDescriptor = fd
        fd = -1
        return rawDescriptor
    }

    func unsafe<R>(_ block: (RAWBSD) throws -> R ) rethrows -> R {
        return try block(fd)
    }

    // MARK: File specific operations

    public func read(count: Int) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: count)
        let bytesRead = Glibc.read(fd, &buffer, count)
        guard bytesRead >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return Data(buffer.prefix(bytesRead))
    }

    public func write(_ data: Data) throws -> Int {
        let bytesWritten = data.withUnsafeBytes { ptr -> Int in
            let n = Glibc.write(fd, ptr.baseAddress, data.count)
            return n
        }
        guard bytesWritten >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return bytesWritten
    }

    public func duplicate() throws -> Self {
        let dupFD = Glibc.dup(fd)
        guard dupFD >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return Self(dupFD)
    }

    public func setNonBlocking(_ nonBlocking: Bool = true) throws {
        let flags = Glibc.fcntl(fd, Glibc.F_GETFL)
        guard flags >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }

        let newFlags = nonBlocking ? (flags | Glibc.O_NONBLOCK) : (flags & ~Glibc.O_NONBLOCK)
        guard Glibc.fcntl(fd, Glibc.F_SETFL, newFlags) >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
    }

    public func getFlags() throws -> Int32 {
        let flags = Glibc.fcntl(fd, Glibc.F_GETFL)
        guard flags >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return flags
    }
}
