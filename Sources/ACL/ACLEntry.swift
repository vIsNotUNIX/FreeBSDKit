/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CACL
import Glibc

/// An entry in an ACL.
///
/// Each ACL entry specifies permissions for a particular user, group, or
/// other entity. POSIX.1e and NFSv4 ACLs have different entry semantics.
///
/// - Note: ACLEntry holds a pointer into the parent ACL's memory. It is only
///   valid while the parent ACL exists. Do not store entries beyond the
///   lifetime of the ACL.
public struct ACLEntry {
    /// The underlying entry handle.
    /// Note: This is only valid while the parent ACL exists.
    private let entry: acl_entry_t

    /// Creates an entry wrapper.
    internal init(entry: acl_entry_t) {
        self.entry = entry
    }

    // MARK: - Tag Type

    /// The tag type identifying what this entry applies to.
    public var tag: Tag {
        get {
            var tagType: acl_tag_t = 0
            if acl_get_tag_type(entry, &tagType) != 0 {
                return .undefined
            }
            return Tag(rawValue: tagType) ?? .undefined
        }
    }

    /// Sets the tag type.
    ///
    /// - Parameter tag: The new tag type.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(tag: Tag) throws {
        if acl_set_tag_type(entry, tag.rawValue) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    // MARK: - Qualifier (User/Group ID)

    /// The qualifier (user or group ID) for USER and GROUP tag types.
    public var qualifier: uid_t? {
        get {
            guard tag == .user || tag == .group else {
                return nil
            }
            guard let ptr = acl_get_qualifier(entry) else {
                return nil
            }
            let id = ptr.assumingMemoryBound(to: uid_t.self).pointee
            acl_free(ptr)
            return id
        }
    }

    /// Sets the qualifier (user or group ID).
    ///
    /// - Parameter qualifier: The user or group ID.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(qualifier: uid_t) throws {
        var uid = qualifier
        if acl_set_qualifier(entry, &uid) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    // MARK: - Permissions

    /// The POSIX.1e permissions for this entry.
    public var permissions: Permissions {
        get {
            var permset: acl_permset_t?
            if acl_get_permset(entry, &permset) != 0 {
                return []
            }
            guard let ps = permset else { return [] }

            var result: Permissions = []
            if acl_get_perm_np(ps, CACL_READ) != 0 {
                result.insert(.read)
            }
            if acl_get_perm_np(ps, CACL_WRITE) != 0 {
                result.insert(.write)
            }
            if acl_get_perm_np(ps, CACL_EXECUTE) != 0 {
                result.insert(.execute)
            }
            return result
        }
    }

    /// Sets the POSIX.1e permissions.
    ///
    /// - Parameter permissions: The permissions to set.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(permissions: Permissions) throws {
        var permset: acl_permset_t?
        if acl_get_permset(entry, &permset) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
        guard let ps = permset else {
            throw ACL.Error.invalidACL
        }

        acl_clear_perms(ps)

        if permissions.contains(.read) {
            acl_add_perm(ps, CACL_READ)
        }
        if permissions.contains(.write) {
            acl_add_perm(ps, CACL_WRITE)
        }
        if permissions.contains(.execute) {
            acl_add_perm(ps, CACL_EXECUTE)
        }

        if acl_set_permset(entry, ps) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    /// The NFSv4 permissions for this entry.
    public var nfs4Permissions: NFS4Permissions {
        get {
            var permset: acl_permset_t?
            if acl_get_permset(entry, &permset) != 0 {
                return []
            }
            guard let ps = permset else { return [] }

            var result: NFS4Permissions = []

            if acl_get_perm_np(ps, CACL_READ_DATA) != 0 {
                result.insert(.readData)
            }
            if acl_get_perm_np(ps, CACL_WRITE_DATA) != 0 {
                result.insert(.writeData)
            }
            if acl_get_perm_np(ps, CACL_APPEND_DATA) != 0 {
                result.insert(.appendData)
            }
            if acl_get_perm_np(ps, CACL_READ_NAMED_ATTRS) != 0 {
                result.insert(.readNamedAttrs)
            }
            if acl_get_perm_np(ps, CACL_WRITE_NAMED_ATTRS) != 0 {
                result.insert(.writeNamedAttrs)
            }
            if acl_get_perm_np(ps, CACL_EXECUTE) != 0 {
                result.insert(.execute)
            }
            if acl_get_perm_np(ps, CACL_DELETE_CHILD) != 0 {
                result.insert(.deleteChild)
            }
            if acl_get_perm_np(ps, CACL_READ_ATTRIBUTES) != 0 {
                result.insert(.readAttributes)
            }
            if acl_get_perm_np(ps, CACL_WRITE_ATTRIBUTES) != 0 {
                result.insert(.writeAttributes)
            }
            if acl_get_perm_np(ps, CACL_DELETE) != 0 {
                result.insert(.delete)
            }
            if acl_get_perm_np(ps, CACL_READ_ACL) != 0 {
                result.insert(.readACL)
            }
            if acl_get_perm_np(ps, CACL_WRITE_ACL) != 0 {
                result.insert(.writeACL)
            }
            if acl_get_perm_np(ps, CACL_WRITE_OWNER) != 0 {
                result.insert(.writeOwner)
            }
            if acl_get_perm_np(ps, CACL_SYNCHRONIZE) != 0 {
                result.insert(.synchronize)
            }

            return result
        }
    }

    /// Sets the NFSv4 permissions.
    ///
    /// - Parameter nfs4Permissions: The NFSv4 permissions to set.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(nfs4Permissions: NFS4Permissions) throws {
        var permset: acl_permset_t?
        if acl_get_permset(entry, &permset) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
        guard let ps = permset else {
            throw ACL.Error.invalidACL
        }

        acl_clear_perms(ps)

        if nfs4Permissions.contains(.readData) { acl_add_perm(ps, CACL_READ_DATA) }
        if nfs4Permissions.contains(.writeData) { acl_add_perm(ps, CACL_WRITE_DATA) }
        if nfs4Permissions.contains(.appendData) { acl_add_perm(ps, CACL_APPEND_DATA) }
        if nfs4Permissions.contains(.readNamedAttrs) { acl_add_perm(ps, CACL_READ_NAMED_ATTRS) }
        if nfs4Permissions.contains(.writeNamedAttrs) { acl_add_perm(ps, CACL_WRITE_NAMED_ATTRS) }
        if nfs4Permissions.contains(.execute) { acl_add_perm(ps, CACL_EXECUTE) }
        if nfs4Permissions.contains(.deleteChild) { acl_add_perm(ps, CACL_DELETE_CHILD) }
        if nfs4Permissions.contains(.readAttributes) { acl_add_perm(ps, CACL_READ_ATTRIBUTES) }
        if nfs4Permissions.contains(.writeAttributes) { acl_add_perm(ps, CACL_WRITE_ATTRIBUTES) }
        if nfs4Permissions.contains(.delete) { acl_add_perm(ps, CACL_DELETE) }
        if nfs4Permissions.contains(.readACL) { acl_add_perm(ps, CACL_READ_ACL) }
        if nfs4Permissions.contains(.writeACL) { acl_add_perm(ps, CACL_WRITE_ACL) }
        if nfs4Permissions.contains(.writeOwner) { acl_add_perm(ps, CACL_WRITE_OWNER) }
        if nfs4Permissions.contains(.synchronize) { acl_add_perm(ps, CACL_SYNCHRONIZE) }

        if acl_set_permset(entry, ps) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    // MARK: - NFSv4 Entry Type

    /// The NFSv4 entry type (allow, deny, audit, alarm).
    public var entryType: EntryType? {
        get {
            var type: acl_entry_type_t = 0
            if acl_get_entry_type_np(entry, &type) != 0 {
                return nil
            }
            return EntryType(rawValue: type)
        }
    }

    /// Sets the NFSv4 entry type.
    ///
    /// - Parameter entryType: The entry type.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(entryType: EntryType) throws {
        if acl_set_entry_type_np(entry, entryType.rawValue) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    // MARK: - NFSv4 Flags

    /// The NFSv4 inheritance flags.
    public var flags: Flags {
        get {
            var flagset: acl_flagset_t?
            if acl_get_flagset_np(entry, &flagset) != 0 {
                return []
            }
            guard let fs = flagset else { return [] }

            var result: Flags = []
            if acl_get_flag_np(fs, CACL_ENTRY_FILE_INHERIT) != 0 {
                result.insert(.fileInherit)
            }
            if acl_get_flag_np(fs, CACL_ENTRY_DIRECTORY_INHERIT) != 0 {
                result.insert(.directoryInherit)
            }
            if acl_get_flag_np(fs, CACL_ENTRY_NO_PROPAGATE_INHERIT) != 0 {
                result.insert(.noPropagateInherit)
            }
            if acl_get_flag_np(fs, CACL_ENTRY_INHERIT_ONLY) != 0 {
                result.insert(.inheritOnly)
            }
            if acl_get_flag_np(fs, CACL_ENTRY_INHERITED) != 0 {
                result.insert(.inherited)
            }
            return result
        }
    }

    /// Sets the NFSv4 inheritance flags.
    ///
    /// - Parameter flags: The flags to set.
    /// - Throws: `ACL.Error` if the operation fails.
    public func set(flags: Flags) throws {
        var flagset: acl_flagset_t?
        if acl_get_flagset_np(entry, &flagset) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
        guard let fs = flagset else {
            throw ACL.Error.invalidACL
        }

        acl_clear_flags_np(fs)

        if flags.contains(.fileInherit) { acl_add_flag_np(fs, CACL_ENTRY_FILE_INHERIT) }
        if flags.contains(.directoryInherit) { acl_add_flag_np(fs, CACL_ENTRY_DIRECTORY_INHERIT) }
        if flags.contains(.noPropagateInherit) { acl_add_flag_np(fs, CACL_ENTRY_NO_PROPAGATE_INHERIT) }
        if flags.contains(.inheritOnly) { acl_add_flag_np(fs, CACL_ENTRY_INHERIT_ONLY) }
        if flags.contains(.inherited) { acl_add_flag_np(fs, CACL_ENTRY_INHERITED) }

        if acl_set_flagset_np(entry, fs) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }

    /// Copies this entry's contents to another entry.
    ///
    /// - Parameter destination: The destination entry.
    /// - Throws: `ACL.Error` if the operation fails.
    public func copy(to destination: ACLEntry) throws {
        if acl_copy_entry(destination.entry, entry) != 0 {
            throw ACL.Error(errno: Glibc.errno)
        }
    }
}
