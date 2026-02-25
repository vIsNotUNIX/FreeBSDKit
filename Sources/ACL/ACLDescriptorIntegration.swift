/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CACL
import Descriptors
import Glibc

// MARK: - Descriptor Integration

extension ACL {
    /// Gets the ACL for a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A file descriptor (FileCapability, etc.).
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Returns: The file's ACL.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func get<D: Descriptor>(
        from descriptor: borrowing D,
        type: ACLType = .access
    ) throws -> ACL where D: ~Copyable {
        try descriptor.unsafe { fd in
            let handle = acl_get_fd_np(fd, type.rawValue)
            if handle == nil {
                throw Error(errno: Glibc.errno)
            }
            return ACL(taking: handle!)
        }
    }

    /// Sets this ACL on a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A file descriptor (FileCapability, etc.).
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func set<D: Descriptor>(
        on descriptor: borrowing D,
        type: ACLType = .access
    ) throws where D: ~Copyable {
        guard let h = unsafeHandle else {
            throw Error.invalidACL
        }
        try descriptor.unsafe { fd in
            if acl_set_fd_np(fd, h, type.rawValue) != 0 {
                throw Error(errno: Glibc.errno)
            }
        }
    }

    /// Deletes the ACL from a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A file descriptor.
    ///   - type: The ACL type to delete.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func delete<D: Descriptor>(
        from descriptor: borrowing D,
        type: ACLType
    ) throws where D: ~Copyable {
        try descriptor.unsafe { fd in
            if acl_delete_fd_np(fd, type.rawValue) != 0 {
                throw Error(errno: Glibc.errno)
            }
        }
    }

    /// Validates this ACL for a specific file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A file descriptor.
    ///   - type: The ACL type.
    /// - Returns: `true` if the ACL would be valid for this file.
    public func isValid<D: Descriptor>(
        for descriptor: borrowing D,
        type: ACLType = .access
    ) -> Bool where D: ~Copyable {
        guard let h = unsafeHandle else { return false }
        return descriptor.unsafe { fd in
            acl_valid_fd_np(fd, type.rawValue, h) == 0
        }
    }
}

// MARK: - Directory-Relative Operations

extension ACL {
    /// Gets the ACL for a file relative to a directory descriptor.
    ///
    /// This is useful in Capsicum capability mode where you have a
    /// DirectoryCapability but cannot use absolute paths.
    ///
    /// - Parameters:
    ///   - relativePath: Path relative to the directory.
    ///   - directory: A directory descriptor.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Returns: The file's ACL.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func get<D: Descriptor>(
        relativePath: String,
        in directory: borrowing D,
        type: ACLType = .access
    ) throws -> ACL where D: ~Copyable {
        // Open the file relative to the directory, then get ACL
        let fd = try directory.unsafe { dirfd -> Int32 in
            let fd = relativePath.withCString { path in
                openat(dirfd, path, O_RDONLY)
            }
            if fd < 0 {
                throw Error(errno: Glibc.errno)
            }
            return fd
        }
        defer { _ = close(fd) }

        let handle = acl_get_fd_np(fd, type.rawValue)
        if handle == nil {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: handle!)
    }

    /// Sets this ACL on a file relative to a directory descriptor.
    ///
    /// - Parameters:
    ///   - relativePath: Path relative to the directory.
    ///   - directory: A directory descriptor.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func set<D: Descriptor>(
        relativePath: String,
        in directory: borrowing D,
        type: ACLType = .access
    ) throws where D: ~Copyable {
        guard let h = unsafeHandle else {
            throw Error.invalidACL
        }

        // Open the file relative to the directory, then set ACL
        let fd = try directory.unsafe { dirfd -> Int32 in
            let fd = relativePath.withCString { path in
                openat(dirfd, path, O_RDONLY)
            }
            if fd < 0 {
                throw Error(errno: Glibc.errno)
            }
            return fd
        }
        defer { _ = close(fd) }

        if acl_set_fd_np(fd, h, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }
}
