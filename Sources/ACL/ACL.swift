/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CACL
import Glibc

/// Swift interface to FreeBSD's POSIX.1e and NFSv4 Access Control Lists.
///
/// ACLs provide fine-grained access control beyond traditional Unix permissions.
/// FreeBSD supports two ACL types:
/// - **POSIX.1e ACLs**: Extended Unix permissions with user/group entries
/// - **NFSv4 ACLs**: Rich ACLs with allow/deny entries and inheritance
///
/// ## Usage
///
/// ```swift
/// // Get ACL from a file
/// var acl = try ACL.get(path: "/path/to/file")
///
/// // Check the ACL brand
/// if acl.brand == .nfs4 {
///     print("NFSv4 ACL")
/// }
///
/// // Iterate over entries
/// for entry in acl {
///     print("Tag: \(entry.tag), Permissions: \(entry.permissions)")
/// }
///
/// // Create a new POSIX.1e ACL from mode
/// var acl = ACL.fromMode(0o755)
///
/// // Set ACL on a file
/// try acl.set(path: "/path/to/file", type: .access)
/// ```
public struct ACL: ~Copyable {
    /// The underlying acl_t handle.
    private var handle: acl_t?

    /// Creates an empty ACL with space for the specified number of entries.
    ///
    /// - Parameter count: Initial entry capacity (default: 4).
    /// - Throws: `ACL.Error` if allocation fails.
    public init(count: Int = 4) throws {
        handle = acl_init(Int32(count))
        if handle == nil {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Creates an ACL by taking ownership of an existing acl_t handle.
    ///
    /// - Parameter handle: The acl_t handle to take ownership of.
    internal init(taking handle: acl_t) {
        self.handle = handle
    }

    deinit {
        if let h = handle {
            acl_free(h)
        }
    }

    // MARK: - File Operations

    /// Gets the ACL for a file path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Returns: The file's ACL.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func get(path: String, type: ACLType = .access) throws -> ACL {
        let handle = acl_get_file(path, type.rawValue)
        if handle == nil {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: handle!)
    }

    /// Gets the ACL for a symbolic link (not following it).
    ///
    /// - Parameters:
    ///   - path: The symlink path.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Returns: The symlink's ACL.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func getLink(path: String, type: ACLType = .access) throws -> ACL {
        let handle = acl_get_link_np(path, type.rawValue)
        if handle == nil {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: handle!)
    }

    /// Gets the ACL for a file descriptor.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Returns: The file's ACL.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func get(fd: Int32, type: ACLType = .access) throws -> ACL {
        let handle = acl_get_fd_np(fd, type.rawValue)
        if handle == nil {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: handle!)
    }

    /// Sets this ACL on a file path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(path: String, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_file(path, type.rawValue, h) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Sets this ACL on a symbolic link (not following it).
    ///
    /// - Parameters:
    ///   - path: The symlink path.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func setLink(path: String, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_link_np(path, type.rawValue, h) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Sets this ACL on a file descriptor.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(fd: Int32, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_fd_np(fd, h, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Deletes the ACL from a file path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to delete.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func delete(path: String, type: ACLType) throws {
        if acl_delete_file_np(path, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Deletes the ACL from a symbolic link.
    ///
    /// - Parameters:
    ///   - path: The symlink path.
    ///   - type: The ACL type to delete.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func deleteLink(path: String, type: ACLType) throws {
        if acl_delete_link_np(path, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Deletes the ACL from a file descriptor.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor.
    ///   - type: The ACL type to delete.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func delete(fd: Int32, type: ACLType) throws {
        if acl_delete_fd_np(fd, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Deletes the default ACL from a directory.
    ///
    /// - Parameter path: The directory path.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func deleteDefault(path: String) throws {
        if acl_delete_def_file(path) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    // MARK: - Creation Helpers

    /// Creates a POSIX.1e ACL from a Unix mode.
    ///
    /// - Parameter mode: The Unix permission mode (e.g., 0o755).
    /// - Returns: A POSIX.1e ACL representing the mode.
    public static func fromMode(_ mode: mode_t) -> ACL? {
        guard let handle = acl_from_mode_np(mode) else {
            return nil
        }
        return ACL(taking: handle)
    }

    /// Creates an ACL from a text representation.
    ///
    /// - Parameter text: The text representation (e.g., "user::rwx,group::r-x,other::r-x").
    /// - Returns: The parsed ACL, or nil if parsing fails.
    public static func fromText(_ text: String) -> ACL? {
        guard let handle = acl_from_text(text) else {
            return nil
        }
        return ACL(taking: handle)
    }

    /// Duplicates this ACL.
    ///
    /// - Returns: A copy of this ACL.
    /// - Throws: `ACL.Error` if duplication fails.
    public func duplicate() throws -> ACL {
        guard let h = handle else {
            throw Error.invalidACL
        }
        guard let dup = acl_dup(h) else {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: dup)
    }

    // MARK: - Properties

    /// The ACL brand (POSIX.1e or NFSv4).
    public var brand: Brand {
        guard let h = handle else {
            return .unknown
        }
        var brandValue: Int32 = 0
        if acl_get_brand_np(h, &brandValue) != 0 {
            return .unknown
        }
        return Brand(rawValue: brandValue) ?? .unknown
    }

    /// Whether this ACL is trivial (equivalent to Unix mode bits only).
    public var isTrivial: Bool {
        guard let h = handle else {
            return true
        }
        var trivial: Int32 = 0
        if acl_is_trivial_np(h, &trivial) != 0 {
            return true
        }
        return trivial != 0
    }

    /// Validates the ACL structure.
    ///
    /// - Returns: `true` if the ACL is valid.
    public var isValid: Bool {
        guard let h = handle else {
            return false
        }
        return acl_valid(h) == 0
    }

    /// The text representation of this ACL.
    public var text: String? {
        guard let h = handle else {
            return nil
        }
        guard let cstr = acl_to_text(h, nil) else {
            return nil
        }
        let result = String(cString: cstr)
        acl_free(cstr)
        return result
    }

    /// The text representation with options.
    ///
    /// - Parameter options: Text output options.
    /// - Returns: The text representation.
    public func text(options: TextOptions) -> String? {
        guard let h = handle else {
            return nil
        }
        guard let cstr = acl_to_text_np(h, nil, options.rawValue) else {
            return nil
        }
        let result = String(cString: cstr)
        acl_free(cstr)
        return result
    }

    /// Converts to equivalent Unix mode if possible.
    ///
    /// - Returns: The equivalent mode, or nil if not expressible as a mode.
    public var equivalentMode: mode_t? {
        guard let h = handle else {
            return nil
        }
        var mode: mode_t = 0
        if acl_equiv_mode_np(h, &mode) != 0 {
            return nil
        }
        return mode
    }

    // MARK: - Entry Management

    /// Creates a new entry in this ACL.
    ///
    /// - Returns: The new entry.
    /// - Throws: `ACL.Error` if creation fails.
    public mutating func createEntry() throws -> ACLEntry {
        guard handle != nil else {
            throw Error.invalidACL
        }
        var entry: acl_entry_t?
        if acl_create_entry(&handle, &entry) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return ACLEntry(entry: entry!)
    }

    /// Creates a new entry at a specific index.
    ///
    /// - Parameter index: The index to insert at.
    /// - Returns: The new entry.
    /// - Throws: `ACL.Error` if creation fails.
    public mutating func createEntry(at index: Int) throws -> ACLEntry {
        guard handle != nil else {
            throw Error.invalidACL
        }
        var entry: acl_entry_t?
        if acl_create_entry_np(&handle, &entry, Int32(index)) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return ACLEntry(entry: entry!)
    }

    /// Deletes an entry at a specific index.
    ///
    /// - Parameter index: The index to delete.
    /// - Throws: `ACL.Error` if deletion fails.
    public mutating func deleteEntry(at index: Int) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_delete_entry_np(h, Int32(index)) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Calculates and sets the mask entry for POSIX.1e ACLs.
    ///
    /// - Throws: `ACL.Error` if calculation fails.
    public mutating func calculateMask() throws {
        guard handle != nil else {
            throw Error.invalidACL
        }
        if acl_calc_mask(&handle) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Strips extended ACL entries, leaving only the base entries.
    ///
    /// - Parameter recalculateMask: Whether to recalculate the mask entry.
    /// - Returns: A new ACL with only base entries.
    /// - Throws: `ACL.Error` if stripping fails.
    public func stripped(recalculateMask: Bool = true) throws -> ACL {
        guard let h = handle else {
            throw Error.invalidACL
        }
        guard let stripped = acl_strip_np(h, recalculateMask ? 1 : 0) else {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: stripped)
    }

    // MARK: - Internal

    /// Provides access to the underlying handle for iteration.
    internal var unsafeHandle: acl_t? {
        handle
    }
}

// MARK: - Iteration Support

extension ACL {
    /// An iterator for ACL entries.
    public struct EntryIterator: IteratorProtocol {
        private var acl: acl_t?
        private var first = true

        init(acl: acl_t?) {
            self.acl = acl
        }

        public mutating func next() -> ACLEntry? {
            guard let acl = acl else { return nil }

            var entry: acl_entry_t?
            let entryId = first ? CACL_FIRST_ENTRY : CACL_NEXT_ENTRY
            first = false

            let result = acl_get_entry(acl, entryId, &entry)
            if result != 1 {
                return nil
            }
            return ACLEntry(entry: entry!)
        }
    }

    /// Returns an iterator over the ACL entries.
    ///
    /// - Returns: An iterator that yields each entry in the ACL.
    public func makeIterator() -> EntryIterator {
        EntryIterator(acl: handle)
    }

    /// Iterates over all entries in the ACL.
    ///
    /// - Parameter body: A closure called for each entry.
    public func forEachEntry(_ body: (ACLEntry) throws -> Void) rethrows {
        var iterator = makeIterator()
        while let entry = iterator.next() {
            try body(entry)
        }
    }

    /// Returns all entries as an array.
    ///
    /// - Returns: An array of all ACL entries.
    public var entries: [ACLEntry] {
        var result: [ACLEntry] = []
        var iterator = makeIterator()
        while let entry = iterator.next() {
            result.append(entry)
        }
        return result
    }
}
