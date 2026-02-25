/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Descriptors
import Foundation
import FreeBSDKit

// MARK: - DirectoryCapability

/// A capability-wrapped directory file descriptor for use with `*at()` system calls.
///
/// `DirectoryCapability` provides capability-safe access to a directory, enabling
/// file operations relative to that directory. This is essential for Capsicum
/// capability mode where absolute paths and `open()` are forbidden.
///
/// ## Capability Mode Safety
///
/// When combined with `O_RESOLVE_BENEATH` or `AT_RESOLVE_BENEATH`, all operations
/// are confined to the directory hierarchy beneath the opened directory. Attempts
/// to escape via `..` or symlinks return `ENOTCAPABLE`.
///
/// ## Example
/// ```swift
/// // Open a directory before entering capability mode
/// let dataDir = try DirectoryCapability.open(path: "/var/data")
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // All file operations now use the directory capability
/// let file = try dataDir.openFileCapability(path: "config.json",
///                                            flags: [.readOnly, .resolveBeneath])
/// let subdir = try dataDir.openDirectoryCapability(path: "subdir",
///                                                   flags: [.resolveBeneath])
/// ```
///
/// ## Capsicum Rights
///
/// Common rights for directory descriptors:
/// - `CAP_LOOKUP` - Required for all path-based operations
/// - `CAP_READ` - Read directory entries
/// - `CAP_WRITE` - Create/delete files in directory
/// - `CAP_FSTAT` - Stat files in directory
/// - `CAP_FSTATAT` - Alias for `CAP_FSTAT` + `CAP_LOOKUP`
/// - `CAP_UNLINKAT` - Delete files
/// - `CAP_MKDIRAT` - Create directories
/// - `CAP_RENAMEAT_SOURCE` / `CAP_RENAMEAT_TARGET` - Rename operations
public struct DirectoryCapability: Capability, DirectoryDescriptor, ~Copyable {
    public typealias RAWBSD = Int32
    private var handle: RawCapabilityHandle

    public init(_ value: RAWBSD) {
        self.handle = RawCapabilityHandle(value)
    }

    public consuming func close() {
        handle.close()
    }

    public consuming func take() -> RAWBSD {
        return handle.take()
    }

    public func unsafe<R>(_ block: (RAWBSD) throws -> R) rethrows -> R where R: ~Copyable {
        try handle.unsafe(block)
    }

    // MARK: - Factory Methods

    /// Opens a directory at the given path.
    ///
    /// - Parameters:
    ///   - path: Absolute or relative path to the directory
    ///   - flags: Additional open flags (`.closeOnExec` and `.directory` are always set)
    /// - Returns: A new `DirectoryCapability`
    /// - Throws: System error if the directory cannot be opened
    public static func open(path: String, flags: OpenAtFlags = []) throws -> DirectoryCapability {
        let dirFlags = flags.union([.directory, .closeOnExec])
        let fd = path.withCString { cpath in
            Glibc.open(cpath, dirFlags.rawValue)
        }
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return DirectoryCapability(fd)
    }

    /// Opens a directory relative to the given directory descriptor.
    ///
    /// - Parameters:
    ///   - dirfd: Base directory descriptor
    ///   - path: Path relative to `dirfd`
    ///   - flags: Additional open flags
    /// - Returns: A new `DirectoryCapability`
    public static func openAt(
        dirfd: borrowing some DirectoryDescriptor,
        path: String,
        flags: OpenAtFlags = []
    ) throws -> DirectoryCapability {
        let fd = try dirfd.openDirectory(path: path, flags: flags)
        return DirectoryCapability(fd)
    }

    // MARK: - Typed Capability Returns

    /// Opens a file relative to this directory and returns a `FileCapability`.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Open flags
    ///   - mode: Creation mode if `.create` flag is set
    /// - Returns: A new `FileCapability`
    public func openFileCapability(
        path: String,
        flags: OpenAtFlags,
        mode: mode_t = 0o644
    ) throws -> FileCapability {
        let fd = try openFile(path: path, flags: flags, mode: mode)
        return FileCapability(fd)
    }

    /// Opens a subdirectory relative to this directory and returns a `DirectoryCapability`.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Open flags (`.resolveBeneath` recommended for capability mode)
    /// - Returns: A new `DirectoryCapability`
    public func openDirectoryCapability(
        path: String,
        flags: OpenAtFlags = []
    ) throws -> DirectoryCapability {
        let fd = try openDirectory(path: path, flags: flags)
        return DirectoryCapability(fd)
    }

    // MARK: - Directory Listing

    /// Lists entries in this directory.
    ///
    /// - Returns: Array of directory entry names (excluding "." and "..")
    /// - Note: This reads all entries into memory. For large directories,
    ///         consider using `fdopendir()` directly for streaming access.
    public func listEntries() throws -> [String] {
        // Use fdopendir with a duplicated fd (fdopendir takes ownership)
        let dupFd = try self.unsafe { fd in
            let d = Glibc.dup(fd)
            guard d >= 0 else {
                try BSDError.throwErrno(errno)
            }
            return d
        }

        guard let dir = Glibc.fdopendir(dupFd) else {
            Glibc.close(dupFd)
            try BSDError.throwErrno(errno)
        }
        defer { Glibc.closedir(dir) }

        var entries: [String] = []
        while let entry = Glibc.readdir(dir) {
            let name = withUnsafePointer(to: entry.pointee.d_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) {
                    String(cString: $0)
                }
            }
            if name != "." && name != ".." {
                entries.append(name)
            }
        }

        return entries
    }

    // MARK: - Convenience Methods

    /// Checks if a path exists relative to this directory.
    public func exists(path: String) throws -> Bool {
        do {
            _ = try stat(path: path)
            return true
        } catch let error as BSDError {
            if case .posix(let posixError) = error, posixError.code == .ENOENT {
                return false
            }
            throw error
        }
    }

    /// Checks if a path is a directory.
    public func isDirectory(path: String) throws -> Bool {
        let st = try stat(path: path)
        return (st.st_mode & S_IFMT) == S_IFDIR
    }

    /// Checks if a path is a regular file.
    public func isFile(path: String) throws -> Bool {
        let st = try stat(path: path)
        return (st.st_mode & S_IFMT) == S_IFREG
    }

    /// Checks if a path is a symbolic link.
    public func isSymlink(path: String) throws -> Bool {
        let st = try stat(path: path, flags: .symlinkNoFollow)
        return (st.st_mode & S_IFMT) == S_IFLNK
    }
}
