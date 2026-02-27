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
/// var acl = try ACL(contentsOf: "/path/to/file")
///
/// // Check the ACL brand
/// if acl.brand == .nfs4 {
///     print("NFSv4 ACL")
/// }
///
/// // Iterate over entries
/// for entry in acl.entries {
///     print("Tag: \(entry.tag), Permissions: \(entry.permissions)")
/// }
///
/// // Create a new POSIX.1e ACL from mode
/// var acl = ACL(mode: 0o755)
///
/// // Apply ACL to a file
/// try acl.apply(to: "/path/to/file", type: .access)
/// ```
public struct ACL: ~Copyable {
    /// The underlying acl_t handle.
    private var handle: acl_t?

    // MARK: - Initializers

    /// Creates an empty ACL with space for the specified number of entries.
    ///
    /// - Parameter capacity: Initial entry capacity (default: 4).
    /// - Throws: `ACL.Error` if allocation fails.
    public init(capacity: Int = 4) throws {
        handle = acl_init(Int32(capacity))
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

    /// Creates an ACL from the contents of a file at the given path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public init(contentsOf path: String, type: ACLType = .access) throws {
        let h = acl_get_file(path, type.rawValue)
        if h == nil {
            throw Error(errno: Glibc.errno)
        }
        self.handle = h
    }

    /// Creates an ACL from a symbolic link (not following it).
    ///
    /// - Parameters:
    ///   - linkPath: The symlink path.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public init(linkAt linkPath: String, type: ACLType = .access) throws {
        let h = acl_get_link_np(linkPath, type.rawValue)
        if h == nil {
            throw Error(errno: Glibc.errno)
        }
        self.handle = h
    }

    /// Creates an ACL from a file descriptor.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The file descriptor.
    ///   - type: The ACL type to retrieve (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public init(fileDescriptor fd: Int32, type: ACLType = .access) throws {
        let h = acl_get_fd_np(fd, type.rawValue)
        if h == nil {
            throw Error(errno: Glibc.errno)
        }
        self.handle = h
    }

    /// Creates a POSIX.1e ACL from a Unix mode.
    ///
    /// - Parameter mode: The Unix permission mode (e.g., 0o755).
    public init?(mode: mode_t) {
        guard let h = acl_from_mode_np(mode) else {
            return nil
        }
        self.handle = h
    }

    /// Creates an ACL by parsing a text representation.
    ///
    /// - Parameter text: The text representation (e.g., "user::rwx,group::r-x,other::r-x").
    public init?(parsing text: String) {
        guard let h = acl_from_text(text) else {
            return nil
        }
        self.handle = h
    }

    /// Creates an ACL from serialized data.
    ///
    /// - Warning: On FreeBSD, this may return nil (not implemented).
    ///   Use `init(parsing:)` for portable ACL storage.
    ///
    /// - Parameter data: The ACL data bytes from `serialized()`.
    public init?(data: [UInt8]) {
        let h = data.withUnsafeBytes { ptr in
            acl_copy_int(ptr.baseAddress!)
        }
        guard let handle = h else { return nil }
        self.handle = handle
    }

    deinit {
        if let h = handle {
            acl_free(h)
        }
    }

    // MARK: - Applying ACL to Files

    /// Applies this ACL to a file at the given path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func apply(to path: String, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_file(path, type.rawValue, h) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Applies this ACL to a symbolic link (not following it).
    ///
    /// - Parameters:
    ///   - linkPath: The symlink path.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func apply(toLinkAt linkPath: String, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_link_np(linkPath, type.rawValue, h) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Applies this ACL to a file descriptor.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The file descriptor.
    ///   - type: The ACL type to set (default: .access).
    /// - Throws: `ACL.Error` if the operation fails.
    public func apply(toFileDescriptor fd: Int32, type: ACLType = .access) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_set_fd_np(fd, h, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    // MARK: - Removing ACLs from Files

    /// Removes the ACL from a file at the given path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type to remove.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func remove(from path: String, type: ACLType) throws {
        if acl_delete_file_np(path, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes the ACL from a symbolic link.
    ///
    /// - Parameters:
    ///   - linkPath: The symlink path.
    ///   - type: The ACL type to remove.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func remove(fromLinkAt linkPath: String, type: ACLType) throws {
        if acl_delete_link_np(linkPath, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes the ACL from a file descriptor.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The file descriptor.
    ///   - type: The ACL type to remove.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func remove(fromFileDescriptor fd: Int32, type: ACLType) throws {
        if acl_delete_fd_np(fd, type.rawValue) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes the default ACL from a directory.
    ///
    /// - Parameter path: The directory path.
    /// - Throws: `ACL.Error` if the operation fails.
    public static func removeDefault(from path: String) throws {
        if acl_delete_def_file(path) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    // MARK: - Copying

    /// Creates a copy of this ACL.
    ///
    /// - Returns: A new ACL with the same entries.
    /// - Throws: `ACL.Error` if copying fails.
    public func copy() throws -> ACL {
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

    /// Whether the ACL structure is valid.
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

    /// Returns the text representation with the specified options.
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

    /// The equivalent Unix mode, if this ACL can be expressed as one.
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

    /// Adds a new entry to this ACL.
    ///
    /// - Returns: The new entry.
    /// - Throws: `ACL.Error` if creation fails.
    public mutating func addEntry() throws -> ACLEntry {
        guard handle != nil else {
            throw Error.invalidACL
        }
        var entry: acl_entry_t?
        if acl_create_entry(&handle, &entry) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return ACLEntry(entry: entry!)
    }

    /// Inserts a new entry at the specified index.
    ///
    /// - Parameter index: The index at which to insert.
    /// - Returns: The new entry.
    /// - Throws: `ACL.Error` if creation fails.
    public mutating func insertEntry(at index: Int) throws -> ACLEntry {
        guard handle != nil else {
            throw Error.invalidACL
        }
        var entry: acl_entry_t?
        if acl_create_entry_np(&handle, &entry, Int32(index)) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return ACLEntry(entry: entry!)
    }

    /// Removes the entry at the specified index.
    ///
    /// - Parameter index: The index of the entry to remove.
    /// - Throws: `ACL.Error` if removal fails.
    public mutating func removeEntry(at index: Int) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_delete_entry_np(h, Int32(index)) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes the specified entry from this ACL.
    ///
    /// - Warning: The entry must belong to this ACL. Using an entry from
    ///   a different ACL is undefined behavior.
    ///
    /// - Parameter entry: The entry to remove.
    /// - Throws: `ACL.Error` if removal fails.
    public mutating func removeEntry(_ entry: ACLEntry) throws {
        guard let h = handle else {
            throw Error.invalidACL
        }
        if acl_delete_entry(h, entry.unsafeEntry) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Recalculates and updates the mask entry for POSIX.1e ACLs.
    ///
    /// - Throws: `ACL.Error` if calculation fails.
    public mutating func recalculateMask() throws {
        guard handle != nil else {
            throw Error.invalidACL
        }
        if acl_calc_mask(&handle) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Returns a new ACL with extended entries removed.
    ///
    /// - Parameter recalculateMask: Whether to recalculate the mask entry.
    /// - Returns: A new ACL with only base entries.
    /// - Throws: `ACL.Error` if stripping fails.
    public func strippingExtendedEntries(recalculateMask: Bool = true) throws -> ACL {
        guard let h = handle else {
            throw Error.invalidACL
        }
        guard let stripped = acl_strip_np(h, recalculateMask ? 1 : 0) else {
            throw Error(errno: Glibc.errno)
        }
        return ACL(taking: stripped)
    }

    // MARK: - Serialization

    /// Returns the serialized binary representation of this ACL.
    ///
    /// - Warning: On FreeBSD, this may throw ENOSYS (not implemented).
    ///   Use `text` property for portable ACL storage.
    ///
    /// - Returns: The ACL as serialized bytes.
    /// - Throws: `ACL.Error` if serialization fails.
    public func serialized() throws -> [UInt8] {
        guard let h = handle else {
            throw Error.invalidACL
        }

        let maxSize: Int = 8192
        var buffer = [UInt8](repeating: 0, count: maxSize)

        let copied = buffer.withUnsafeMutableBytes { ptr in
            acl_copy_ext(ptr.baseAddress!, h, maxSize)
        }
        if copied < 0 {
            throw Error(errno: Glibc.errno)
        }

        return Array(buffer.prefix(Int(copied)))
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
    public func makeIterator() -> EntryIterator {
        EntryIterator(acl: handle)
    }

    /// All entries in this ACL.
    public var entries: [ACLEntry] {
        var result: [ACLEntry] = []
        var iterator = makeIterator()
        while let entry = iterator.next() {
            result.append(entry)
        }
        return result
    }
}

// MARK: - Deprecated API (for migration)

extension ACL {
    @available(*, deprecated, renamed: "init(capacity:)")
    public init(count: Int = 4) throws {
        try self.init(capacity: count)
    }

    @available(*, deprecated, renamed: "init(contentsOf:type:)")
    public static func get(path: String, type: ACLType = .access) throws -> ACL {
        try ACL(contentsOf: path, type: type)
    }

    @available(*, deprecated, renamed: "init(linkAt:type:)")
    public static func getLink(path: String, type: ACLType = .access) throws -> ACL {
        try ACL(linkAt: path, type: type)
    }

    @available(*, deprecated, renamed: "init(fileDescriptor:type:)")
    public static func get(fd: Int32, type: ACLType = .access) throws -> ACL {
        try ACL(fileDescriptor: fd, type: type)
    }

    @available(*, deprecated, renamed: "init(mode:)")
    public static func fromMode(_ mode: mode_t) -> ACL? {
        ACL(mode: mode)
    }

    @available(*, deprecated, renamed: "init(parsing:)")
    public static func fromText(_ text: String) -> ACL? {
        ACL(parsing: text)
    }

    @available(*, deprecated, renamed: "init(data:)")
    public static func fromData(_ data: [UInt8]) -> ACL? {
        ACL(data: data)
    }

    @available(*, deprecated, renamed: "apply(to:type:)")
    public func set(path: String, type: ACLType = .access) throws {
        try apply(to: path, type: type)
    }

    @available(*, deprecated, renamed: "apply(toLinkAt:type:)")
    public func setLink(path: String, type: ACLType = .access) throws {
        try apply(toLinkAt: path, type: type)
    }

    @available(*, deprecated, renamed: "apply(toFileDescriptor:type:)")
    public func set(fd: Int32, type: ACLType = .access) throws {
        try apply(toFileDescriptor: fd, type: type)
    }

    @available(*, deprecated, renamed: "remove(from:type:)")
    public static func delete(path: String, type: ACLType) throws {
        try remove(from: path, type: type)
    }

    @available(*, deprecated, renamed: "remove(fromLinkAt:type:)")
    public static func deleteLink(path: String, type: ACLType) throws {
        try remove(fromLinkAt: path, type: type)
    }

    @available(*, deprecated, renamed: "remove(fromFileDescriptor:type:)")
    public static func delete(fd: Int32, type: ACLType) throws {
        try remove(fromFileDescriptor: fd, type: type)
    }

    @available(*, deprecated, renamed: "removeDefault(from:)")
    public static func deleteDefault(path: String) throws {
        try removeDefault(from: path)
    }

    @available(*, deprecated, renamed: "copy()")
    public func duplicate() throws -> ACL {
        try copy()
    }

    @available(*, deprecated, renamed: "addEntry()")
    public mutating func createEntry() throws -> ACLEntry {
        try addEntry()
    }

    @available(*, deprecated, renamed: "insertEntry(at:)")
    public mutating func createEntry(at index: Int) throws -> ACLEntry {
        try insertEntry(at: index)
    }

    @available(*, deprecated, renamed: "removeEntry(at:)")
    public mutating func deleteEntry(at index: Int) throws {
        try removeEntry(at: index)
    }

    @available(*, deprecated, renamed: "removeEntry(_:)")
    public mutating func deleteEntry(_ entry: ACLEntry) throws {
        try removeEntry(entry)
    }

    @available(*, deprecated, renamed: "recalculateMask()")
    public mutating func calculateMask() throws {
        try recalculateMask()
    }

    @available(*, deprecated, renamed: "strippingExtendedEntries(recalculateMask:)")
    public func stripped(recalculateMask: Bool = true) throws -> ACL {
        try strippingExtendedEntries(recalculateMask: recalculateMask)
    }

    @available(*, deprecated, renamed: "serialized()")
    public func toData() throws -> [UInt8] {
        try serialized()
    }
}
