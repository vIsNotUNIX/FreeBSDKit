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

/// A protocol representing a generic BSD descriptor resource, such as a file descriptor,
/// socket, kqueue, or process descriptor.
///
/// `Descriptor` extends `BSDResource` with a few properties and behaviors common to
/// all descriptors:
/// - They have an underlying raw BSD resource (`Int32`).
/// - They can be closed to release the resource.
/// - They can be sent across concurrency domains (`Sendable`).
///
/// Conforming types should provide an initializer from the raw descriptor and implement
/// proper cleanup via `close()`.
public protocol Descriptor: BSDResource, Sendable, ~Copyable
where RAWBSD == Int32 {
    /// Initializes the descriptor from a raw `Int32` resource.
    ///
    /// - Parameter value: The raw BSD descriptor.
    init(_ value: RAWBSD)

    /// Consumes the descriptor and closes/releases the underlying resource.
    ///
    /// After calling this method, the descriptor should no longer be used.
    consuming func close()

    func fstat() throws -> stat
    // TODO: OptionSet the flags
    func getFlags() throws -> Int32
    // TODO: OptionSet the flags
    func setFlags(_ flags: Int32) throws

    func setCloseOnExec(_ enabled: Bool) throws

    func getCloseOnExec() throws -> Bool
}


extension Descriptor where Self: ~Copyable  {
    /// Duplicate the descriptor.
    ///
    /// Returns a new descriptor referring to the same kernel resource.
    public func duplicate() throws -> Self {
        return try self.unsafe { (fd: Int32) in
            let newFD = Glibc.dup(fd)
            if newFD == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
            return Self(newFD)
        }
    }

    public func fstat() throws -> stat {
        return try self.unsafe { (fd: Int32) in
            var st = stat()
            if Glibc.fstat(fd, &st) != 0 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
            return st
        }
    }
    // TODO make Swifty
    // TODO: OptionSet the flags
    public func getFlags() throws -> Int32 {
        return try self.unsafe { (fd: Int32) in
            let flags = Glibc.fcntl(fd, F_GETFL)
            if flags == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
            return flags
        }
    }
    // TODO make Swifty
    // TODO: OptionSet the flags
    public func setFlags(_ flags: Int32) throws {
        try self.unsafe { (fd: Int32) in
            if Glibc.fcntl(fd, F_SETFL, flags) == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
        }
    }

    // TODO: Make Swifty
    public func setCloseOnExec(_ enabled: Bool) throws {
        try self.unsafe { (fd: Int32) in
            var flags = Glibc.fcntl(fd, F_GETFD)
            if flags == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
            if enabled { flags |= FD_CLOEXEC } else { flags &= ~FD_CLOEXEC }
            if Glibc.fcntl(fd, F_SETFD, flags) == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
        }
    }
    // TODO: Make Swifty
    public func getCloseOnExec() throws -> Bool {
        return try self.unsafe { (fd: Int32) in
            let flags = Glibc.fcntl(fd, F_GETFD)
            if flags == -1 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
            return (flags & FD_CLOEXEC) != 0
        }
    }
}