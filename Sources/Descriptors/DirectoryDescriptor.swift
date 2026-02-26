/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - OpenAtFlags

/// Flags for `openat()` system call.
public struct OpenAtFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Open for reading only.
    public static let readOnly = OpenAtFlags(rawValue: O_RDONLY)
    /// Open for writing only.
    public static let writeOnly = OpenAtFlags(rawValue: O_WRONLY)
    /// Open for reading and writing.
    public static let readWrite = OpenAtFlags(rawValue: O_RDWR)

    /// Create file if it doesn't exist.
    public static let create = OpenAtFlags(rawValue: O_CREAT)
    /// Fail if file exists (with create).
    public static let exclusive = OpenAtFlags(rawValue: O_EXCL)
    /// Truncate file to zero length.
    public static let truncate = OpenAtFlags(rawValue: O_TRUNC)
    /// Append on each write.
    public static let append = OpenAtFlags(rawValue: O_APPEND)
    /// Non-blocking mode.
    public static let nonBlocking = OpenAtFlags(rawValue: O_NONBLOCK)
    /// Set close-on-exec flag.
    public static let closeOnExec = OpenAtFlags(rawValue: O_CLOEXEC)
    /// Open directory (for openat base).
    public static let directory = OpenAtFlags(rawValue: O_DIRECTORY)
    /// Don't follow symlinks.
    public static let noFollow = OpenAtFlags(rawValue: O_NOFOLLOW)

    /// Restrict resolution to beneath the directory fd.
    /// Returns ENOTCAPABLE if path escapes. Essential for capability mode.
    public static let resolveBeneath = OpenAtFlags(rawValue: O_RESOLVE_BENEATH)

    /// If path is empty, operate on the directory fd itself.
    public static let emptyPath = OpenAtFlags(rawValue: O_EMPTY_PATH)
}

// MARK: - DirectoryEntryType

/// File type from directory entry.
public enum DirectoryEntryType: UInt8, Sendable {
    case unknown = 0
    case fifo = 1
    case characterDevice = 2
    case directory = 4
    case blockDevice = 6
    case regular = 8
    case symbolicLink = 10
    case socket = 12
    case whiteout = 14

    /// Initialize from dirent d_type field.
    public init(dtype: UInt8) {
        self = DirectoryEntryType(rawValue: dtype) ?? .unknown
    }
}

// MARK: - DirectoryEntry

/// A parsed directory entry.
public struct DirectoryEntry: Sendable {
    /// The file's inode number.
    public let inode: ino_t

    /// The type of file (regular, directory, symlink, etc.).
    public let type: DirectoryEntryType

    /// The entry's name.
    public let name: String

    public init(inode: ino_t, type: DirectoryEntryType, name: String) {
        self.inode = inode
        self.type = type
        self.name = name
    }
}

// MARK: - AtFlags

/// Flags for `*at()` system calls like fstatat, unlinkat, etc.
public struct AtFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Don't follow symlinks (for fstatat, fchmodat, etc).
    public static let symlinkNoFollow = AtFlags(rawValue: AT_SYMLINK_NOFOLLOW)

    /// Remove directory (for unlinkat).
    public static let removeDir = AtFlags(rawValue: AT_REMOVEDIR)

    /// Restrict resolution to beneath the directory fd.
    public static let resolveBeneath = AtFlags(rawValue: AT_RESOLVE_BENEATH)

    /// If path is empty, operate on the directory fd itself.
    public static let emptyPath = AtFlags(rawValue: AT_EMPTY_PATH)
}

// MARK: - DirectoryDescriptor

/// A descriptor representing an open directory for use with `*at()` system calls.
///
/// Directory descriptors enable capability-safe file operations by providing a
/// base directory from which relative paths are resolved. Combined with
/// `O_RESOLVE_BENEATH`, operations are confined to the directory hierarchy.
///
/// ## Capability Mode
///
/// In Capsicum capability mode:
/// - `open()` is forbidden; only `openat()` is allowed
/// - Absolute paths are forbidden
/// - `O_RESOLVE_BENEATH` prevents escaping the directory hierarchy via `..`
///
/// ## Example
/// ```swift
/// let dir = try DirectoryCapability.open(path: "/var/data")
/// let file = try dir.openFile(path: "subdir/file.txt", flags: [.readOnly, .resolveBeneath])
/// ```
public protocol DirectoryDescriptor: Descriptor, ~Copyable {

    // MARK: - Opening Files

    /// Opens a file relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Open flags (access mode, create, etc.)
    ///   - mode: Creation mode if `.create` flag is set (default: 0o644)
    /// - Returns: A new file descriptor
    func openFile(path: String, flags: OpenAtFlags, mode: mode_t) throws -> Int32

    /// Opens a subdirectory relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Open flags (typically just `.resolveBeneath`)
    /// - Returns: A new directory descriptor (raw fd)
    func openDirectory(path: String, flags: OpenAtFlags) throws -> Int32

    // MARK: - Stat Operations

    /// Stats a file relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Flags controlling symlink behavior
    /// - Returns: The stat structure
    func stat(path: String, flags: AtFlags) throws -> stat

    // MARK: - Directory Modification

    /// Creates a directory relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - mode: Directory permissions (default: 0o755)
    func mkdir(path: String, mode: mode_t) throws

    /// Removes a file or empty directory relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: Use `.removeDir` to remove directories
    func unlink(path: String, flags: AtFlags) throws

    /// Renames a file within this directory.
    ///
    /// - Parameters:
    ///   - oldPath: Current path relative to this directory
    ///   - newPath: New path relative to this directory
    func rename(from oldPath: String, to newPath: String) throws

    // MARK: - Symlinks

    /// Creates a symbolic link relative to this directory.
    ///
    /// - Parameters:
    ///   - target: The target the symlink points to
    ///   - path: Path of the symlink relative to this directory
    func symlink(target: String, path: String) throws

    /// Reads a symbolic link relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    /// - Returns: The target of the symlink
    func readlink(path: String) throws -> String

    // MARK: - Hard Links

    /// Creates a hard link relative to this directory.
    ///
    /// - Parameters:
    ///   - existingPath: Path to existing file
    ///   - newPath: Path for new link
    ///   - flags: Flags controlling symlink behavior
    func link(from existingPath: String, to newPath: String, flags: AtFlags) throws

    // MARK: - Permissions

    /// Changes file mode relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - mode: New file mode
    ///   - flags: Flags controlling symlink behavior
    func chmod(path: String, mode: mode_t, flags: AtFlags) throws

    /// Checks access permissions relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - mode: Access mode to check (R_OK, W_OK, X_OK, F_OK)
    ///   - flags: Flags controlling symlink behavior
    /// - Returns: true if access is permitted
    func access(path: String, mode: Int32, flags: AtFlags) throws -> Bool

    // MARK: - Ownership

    /// Changes owner and group of a file relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - owner: New owner UID, or -1 to leave unchanged
    ///   - group: New group GID, or -1 to leave unchanged
    ///   - flags: Flags controlling symlink behavior
    func chown(path: String, owner: uid_t, group: gid_t, flags: AtFlags) throws

    // MARK: - File Flags

    /// Changes file flags relative to this directory (FreeBSD-specific).
    ///
    /// File flags include UF_IMMUTABLE, UF_APPEND, SF_ARCHIVED, etc.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - flags: New file flags
    ///   - atFlags: Flags controlling symlink behavior
    func chflags(path: String, flags: UInt, atFlags: AtFlags) throws

    // MARK: - Timestamps

    /// Sets access and modification times relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - accessTime: New access time, or nil for current time
    ///   - modificationTime: New modification time, or nil for current time
    ///   - flags: Flags controlling symlink behavior
    func setTimes(path: String, access accessTime: timespec?, modification modificationTime: timespec?, flags: AtFlags) throws

    // MARK: - Special Files

    /// Creates a FIFO (named pipe) relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - mode: File permissions (default: 0o644)
    func mkfifo(path: String, mode: mode_t) throws

    /// Creates a device node relative to this directory.
    ///
    /// - Parameters:
    ///   - path: Path relative to this directory
    ///   - mode: File type and permissions (S_IFCHR, S_IFBLK, etc.)
    ///   - dev: Device number
    func mknod(path: String, mode: mode_t, dev: dev_t) throws

    // MARK: - Directory Reading

    /// Reads raw directory entries into a buffer.
    ///
    /// This is the low-level interface to `getdirentries()`. For most uses,
    /// prefer `readEntries()` which returns parsed `DirectoryEntry` values.
    ///
    /// - Parameters:
    ///   - buffer: Buffer to read into
    ///   - basep: On return, contains the position for the next read
    /// - Returns: Number of bytes read, or 0 at end of directory
    func readEntriesRaw(into buffer: UnsafeMutableRawBufferPointer, basep: inout off_t) throws -> Int

    /// Reads all directory entries.
    ///
    /// Returns parsed directory entries. The directory position is reset
    /// to the beginning before reading.
    ///
    /// - Returns: Array of directory entries
    func readEntries() throws -> [DirectoryEntry]
}

// MARK: - Default Implementations

public extension DirectoryDescriptor where Self: ~Copyable {

    func openFile(path: String, flags: OpenAtFlags, mode: mode_t = 0o644) throws -> Int32 {
        try self.unsafe { dirfd in
            let fd = path.withCString { cpath in
                Glibc.openat(dirfd, cpath, flags.rawValue, mode)
            }
            guard fd >= 0 else {
                try BSDError.throwErrno(errno)
            }
            return fd
        }
    }

    func openDirectory(path: String, flags: OpenAtFlags = []) throws -> Int32 {
        let dirFlags = flags.union([.directory, .closeOnExec])
        return try openFile(path: path, flags: dirFlags, mode: 0)
    }

    func stat(path: String, flags: AtFlags = []) throws -> stat {
        try self.unsafe { dirfd in
            var st = Glibc.stat()
            let result = path.withCString { cpath in
                Glibc.fstatat(dirfd, cpath, &st, flags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
            return st
        }
    }

    func mkdir(path: String, mode: mode_t = 0o755) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.mkdirat(dirfd, cpath, mode)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func unlink(path: String, flags: AtFlags = []) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.unlinkat(dirfd, cpath, flags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func rename(from oldPath: String, to newPath: String) throws {
        try self.unsafe { dirfd in
            let result = oldPath.withCString { oldCPath in
                newPath.withCString { newCPath in
                    Glibc.renameat(dirfd, oldCPath, dirfd, newCPath)
                }
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func symlink(target: String, path: String) throws {
        try self.unsafe { dirfd in
            let result = target.withCString { targetCPath in
                path.withCString { linkCPath in
                    Glibc.symlinkat(targetCPath, dirfd, linkCPath)
                }
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func readlink(path: String) throws -> String {
        try self.unsafe { dirfd in
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
            let len = path.withCString { cpath in
                Glibc.readlinkat(dirfd, cpath, &buffer, buffer.count - 1)
            }
            guard len >= 0 else {
                try BSDError.throwErrno(errno)
            }
            buffer[len] = 0
            return buffer.withUnsafeBytes { ptr in
                let utf8 = ptr.bindMemory(to: UInt8.self)
                let length = utf8.firstIndex(of: 0) ?? utf8.count
                return String(decoding: utf8.prefix(length), as: UTF8.self)
            }
        }
    }

    func link(from existingPath: String, to newPath: String, flags: AtFlags = []) throws {
        try self.unsafe { dirfd in
            let result = existingPath.withCString { existingCPath in
                newPath.withCString { newCPath in
                    Glibc.linkat(dirfd, existingCPath, dirfd, newCPath, flags.rawValue)
                }
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func chmod(path: String, mode: mode_t, flags: AtFlags = []) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.fchmodat(dirfd, cpath, mode, flags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func access(path: String, mode: Int32, flags: AtFlags = []) throws -> Bool {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.faccessat(dirfd, cpath, mode, flags.rawValue)
            }
            if result == 0 {
                return true
            }
            if errno == EACCES || errno == ENOENT {
                return false
            }
            try BSDError.throwErrno(errno)
        }
    }

    func chown(path: String, owner: uid_t, group: gid_t, flags: AtFlags = []) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.fchownat(dirfd, cpath, owner, group, flags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func chflags(path: String, flags: UInt, atFlags: AtFlags = []) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.chflagsat(dirfd, cpath, flags, atFlags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func setTimes(
        path: String,
        access accessTime: timespec? = nil,
        modification modificationTime: timespec? = nil,
        flags: AtFlags = []
    ) throws {
        try self.unsafe { dirfd in
            var times: [timespec] = [
                accessTime ?? timespec(tv_sec: 0, tv_nsec: Int(UTIME_NOW)),
                modificationTime ?? timespec(tv_sec: 0, tv_nsec: Int(UTIME_NOW))
            ]
            let result = path.withCString { cpath in
                Glibc.utimensat(dirfd, cpath, &times, flags.rawValue)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func mkfifo(path: String, mode: mode_t = 0o644) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.mkfifoat(dirfd, cpath, mode)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func mknod(path: String, mode: mode_t, dev: dev_t) throws {
        try self.unsafe { dirfd in
            let result = path.withCString { cpath in
                Glibc.mknodat(dirfd, cpath, mode, dev)
            }
            guard result == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func readEntriesRaw(into buffer: UnsafeMutableRawBufferPointer, basep: inout off_t) throws -> Int {
        try self.unsafe { dirfd in
            let bytesRead = Glibc.getdirentries(
                dirfd,
                buffer.baseAddress!.assumingMemoryBound(to: CChar.self),
                buffer.count,
                &basep
            )
            guard bytesRead >= 0 else {
                try BSDError.throwErrno(errno)
            }
            return Int(bytesRead)
        }
    }

    func readEntries() throws -> [DirectoryEntry] {
        try self.unsafe { dirfd in
            // Seek to beginning of directory
            guard Glibc.lseek(dirfd, 0, SEEK_SET) == 0 else {
                try BSDError.throwErrno(errno)
            }

            var entries: [DirectoryEntry] = []
            let bufferSize = 8192
            let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 8)
            defer { buffer.deallocate() }

            var basep: off_t = 0

            while true {
                let bytesRead = Glibc.getdirentries(
                    dirfd,
                    buffer.assumingMemoryBound(to: CChar.self),
                    bufferSize,
                    &basep
                )

                if bytesRead < 0 {
                    try BSDError.throwErrno(errno)
                }

                if bytesRead == 0 {
                    break
                }

                // Parse dirent structures from buffer
                var offset = 0
                while offset < bytesRead {
                    let direntPtr = buffer.advanced(by: offset).assumingMemoryBound(to: dirent.self)
                    let entry = direntPtr.pointee

                    let name = withUnsafePointer(to: entry.d_name) { namePtr in
                        namePtr.withMemoryRebound(to: CChar.self, capacity: Int(entry.d_namlen) + 1) { cstr in
                            String(cString: cstr)
                        }
                    }

                    entries.append(DirectoryEntry(
                        inode: entry.d_fileno,
                        type: DirectoryEntryType(dtype: entry.d_type),
                        name: name
                    ))

                    offset += Int(entry.d_reclen)
                }
            }

            return entries
        }
    }
}
