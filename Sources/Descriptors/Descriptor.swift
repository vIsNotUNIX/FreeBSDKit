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

// MARK: - File Status Flags

/// File status flags used with `fcntl(F_GETFL)` / `fcntl(F_SETFL)`.
///
/// This maps directly to the POSIX `O_*` flags.
public struct FileStatusFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let readOnly  = FileStatusFlags(rawValue: O_RDONLY)
    public static let writeOnly = FileStatusFlags(rawValue: O_WRONLY)
    public static let readWrite = FileStatusFlags(rawValue: O_RDWR)

    public static let nonBlocking = FileStatusFlags(rawValue: O_NONBLOCK)
    public static let append      = FileStatusFlags(rawValue: O_APPEND)
    public static let sync        = FileStatusFlags(rawValue: O_SYNC)
}

// MARK: - Descriptor

/// A move-only, sendable BSD descriptor.
///
/// `Descriptor` represents **exclusive ownership** of a BSD file descriptor.
///
/// ### Semantics
/// - Move-only (`~Copyable`)
/// - Sendable across concurrency domains
/// - Must **never** be accessed concurrently
///
/// Ownership may be transferred between tasks, but the descriptor must not
/// be used simultaneously by multiple tasks.
public protocol Descriptor: BSDResource, Sendable, ~Copyable
where RAWBSD == Int32 {

    /// Initialize from a raw BSD file descriptor.
    init(_ value: RAWBSD)

    /// Consume and close the descriptor.
    ///
    /// After calling this method, the descriptor is invalid.
    consuming func close()

    /// Perform `fstat(2)` on the descriptor.
    func stat() throws -> stat

    /// Get file status flags.
    func statusFlags() throws -> FileStatusFlags

    /// Replace file status flags.
    func setStatusFlags(_ flags: FileStatusFlags) throws

    /// Enable or disable close-on-exec (`FD_CLOEXEC`).
    func setCloseOnExec(_ enabled: Bool) throws

    /// Query close-on-exec state.
    var isCloseOnExec: Bool { get throws }
}

public extension Descriptor where Self: ~Copyable {

    /// Duplicate the descriptor using `dup(2)`.
    ///
    /// The returned descriptor refers to the same kernel object
    /// and retains identical capability rights.
    func duplicate() throws -> Self {
        try self.unsafe { fd in
            let newFD = Glibc.dup(fd)
            guard newFD >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return Self(newFD)
        }
    }

    func stat() throws -> stat {
        try self.unsafe { fd in
            var st = Glibc.stat()
            guard Glibc.fstat(fd, &st) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return st
        }
    }

    func statusFlags() throws -> FileStatusFlags {
        try self.unsafe { fd in
            let flags = Glibc.fcntl(fd, F_GETFL)
            guard flags != -1 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return FileStatusFlags(rawValue: flags)
        }
    }

    func setStatusFlags(_ flags: FileStatusFlags) throws {
        try self.unsafe { fd in
            guard Glibc.fcntl(fd, F_SETFL, flags.rawValue) != -1 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    func setCloseOnExec(_ enabled: Bool) throws {
        try self.unsafe { fd in
            var flags = Glibc.fcntl(fd, F_GETFD)
            guard flags != -1 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }

            if enabled {
                flags |= FD_CLOEXEC
            } else {
                flags &= ~FD_CLOEXEC
            }

            guard Glibc.fcntl(fd, F_SETFD, flags) != -1 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    var isCloseOnExec: Bool {
        get throws {
            try self.unsafe { fd in
                let flags = Glibc.fcntl(fd, F_GETFD)
                guard flags != -1 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno)!)
                }
                return (flags & FD_CLOEXEC) != 0
            }
        }
    }

    consuming func toOpaqueRef() -> OpaqueDescriptorRef {
        fatalError()
    }
}