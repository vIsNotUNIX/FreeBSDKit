/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - File Status Flags

public typealias RawDesc = Int32

/// File access mode from `fcntl(F_GETFL)`.
///
/// The access mode is a masked field extracted from the file status word
/// using `O_ACCMODE`. It is distinct from file status flags and cannot be
/// changed after a descriptor is opened.
public enum FileAccessMode: Sendable {
    case readOnly
    case writeOnly
    case readWrite

    init(getfl: Int32) {
        switch getfl & O_ACCMODE {
        case O_WRONLY: self = .writeOnly
        case O_RDWR:   self = .readWrite
        default:       self = .readOnly  // O_RDONLY is 0
        }
    }
}

/// File status flags used with `fcntl(F_GETFL)` / `fcntl(F_SETFL)`.
///
/// These represent the changeable flags that can be modified via `F_SETFL`.
/// The access mode (O_RDONLY/O_WRONLY/O_RDWR) is **not** included, as it
/// is a masked field handled separately via `FileAccessMode`.
public struct FileStatusFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let nonBlocking = FileStatusFlags(rawValue: O_NONBLOCK)
    public static let append      = FileStatusFlags(rawValue: O_APPEND)
    public static let sync        = FileStatusFlags(rawValue: O_SYNC)

    /// Mask of all changeable status flags.
    ///
    /// Used to extract only the settable bits from F_GETFL and to preserve
    /// non-changeable bits when setting flags via F_SETFL.
    static let changeableMask: Int32 = O_NONBLOCK | O_APPEND | O_SYNC
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
    ///
    /// - Important: Conforming types must invalidate internal state (e.g., set
    ///   the stored fd to -1) to prevent accidental reuse via `unsafe`.
    consuming func close()

    /// Perform `fstat(2)` on the descriptor.
    func stat() throws -> stat

    /// Get the file access mode.
    ///
    /// The access mode (read-only, write-only, or read-write) is determined at
    /// open time and cannot be changed.
    func accessMode() throws -> FileAccessMode

    /// Get the changeable file status flags.
    ///
    /// Returns only the flags that can be modified via `setStatusFlags()`,
    /// such as `O_NONBLOCK`, `O_APPEND`, and `O_SYNC`. The access mode is
    /// excluded and available separately via `accessMode()`.
    func statusFlags() throws -> FileStatusFlags

    /// Set the changeable file status flags.
    ///
    /// Only the flags in `FileStatusFlags.changeableMask` are modified.
    /// The access mode and other non-changeable bits are preserved.
    func setStatusFlags(_ flags: FileStatusFlags) throws

    /// Update the changeable file status flags.
    ///
    /// Reads the current flags, applies the closure to modify them, and writes
    /// the result back. This is useful for toggling specific flags without
    /// affecting others.
    ///
    /// Example:
    /// ```swift
    /// try descriptor.updateStatusFlags { flags in
    ///     flags.insert(.nonBlocking)
    /// }
    /// ```
    func updateStatusFlags(_ body: (inout FileStatusFlags) throws -> Void) throws

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
                try BSDError.throwErrno(errno)
            }
            return Self(newFD)
        }
    }

    func stat() throws -> stat {
        try self.unsafe { fd in
            var st = Glibc.stat()
            guard Glibc.fstat(fd, &st) == 0 else {
                try BSDError.throwErrno(errno)
            }
            return st
        }
    }

    func accessMode() throws -> FileAccessMode {
        try self.unsafe { fd in
            let getfl = Glibc.fcntl(fd, F_GETFL)
            guard getfl != -1 else {
                try BSDError.throwErrno(errno)
            }
            return FileAccessMode(getfl: getfl)
        }
    }

    func statusFlags() throws -> FileStatusFlags {
        try self.unsafe { fd in
            let getfl = Glibc.fcntl(fd, F_GETFL)
            guard getfl != -1 else {
                try BSDError.throwErrno(errno)
            }
            // Extract only changeable flags, excluding access mode
            return FileStatusFlags(rawValue: getfl & FileStatusFlags.changeableMask)
        }
    }

    func setStatusFlags(_ flags: FileStatusFlags) throws {
        try self.unsafe { fd in
            // Read current flags to preserve non-changeable bits
            let getfl = Glibc.fcntl(fd, F_GETFL)
            guard getfl != -1 else {
                try BSDError.throwErrno(errno)
            }

            // Preserve non-changeable bits, set only changeable bits from flags
            let newFlags = (getfl & ~FileStatusFlags.changeableMask) | (flags.rawValue & FileStatusFlags.changeableMask)

            guard Glibc.fcntl(fd, F_SETFL, newFlags) != -1 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func updateStatusFlags(_ body: (inout FileStatusFlags) throws -> Void) throws {
        var flags = try statusFlags()
        try body(&flags)
        try setStatusFlags(flags)
    }

    func setCloseOnExec(_ enabled: Bool) throws {
        try self.unsafe { fd in
            var flags = Glibc.fcntl(fd, F_GETFD)
            guard flags != -1 else {
                try BSDError.throwErrno(errno)
            }

            if enabled {
                flags |= FD_CLOEXEC
            } else {
                flags &= ~FD_CLOEXEC
            }

            guard Glibc.fcntl(fd, F_SETFD, flags) != -1 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    var isCloseOnExec: Bool {
        get throws {
            try self.unsafe { fd in
                let flags = Glibc.fcntl(fd, F_GETFD)
                guard flags != -1 else {
                    try BSDError.throwErrno(errno)
                }
                return (flags & FD_CLOEXEC) != 0
            }
        }
    }
    // TODO: Have each type return the descriptor with kind set.
    consuming func toOpaqueRef() -> OpaqueDescriptorRef {
        OpaqueDescriptorRef(self.take())
    }
}