/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CACL
import Glibc


extension ACL {
    /// The type of ACL (access or default).
    public enum ACLType: acl_type_t, Sendable {
        /// Access ACL - controls access to the file itself.
        case access = 0x00000002  // ACL_TYPE_ACCESS

        /// Default ACL - inherited by new files in a directory.
        case `default` = 0x00000003  // ACL_TYPE_DEFAULT

        /// NFSv4 ACL.
        case nfs4 = 0x00000004  // ACL_TYPE_NFS4
    }
}

public typealias ACLType = ACL.ACLType

// MARK: - ACL Brand

extension ACL {
    /// The ACL brand (semantics).
    public enum Brand: Int32, Sendable {
        /// Unknown brand.
        case unknown = 0

        /// POSIX.1e ACL semantics.
        case posix = 1

        /// NFSv4 ACL semantics.
        case nfs4 = 2
    }
}

// MARK: - ACL Entry Tag

extension ACLEntry {
    /// The tag type identifying what an ACL entry applies to.
    public enum Tag: acl_tag_t, Sendable {
        /// Undefined tag.
        case undefined = 0x00000000

        /// The file owner.
        case userObj = 0x00000001

        /// A specific user (qualifier contains UID).
        case user = 0x00000002

        /// The file's owning group.
        case groupObj = 0x00000004

        /// A specific group (qualifier contains GID).
        case group = 0x00000008

        /// The mask entry (POSIX.1e only).
        case mask = 0x00000010

        /// All other users (POSIX.1e).
        case other = 0x00000020

        /// Everyone (NFSv4 only).
        case everyone = 0x00000040
    }
}

// MARK: - POSIX.1e Permissions

extension ACLEntry {
    /// POSIX.1e ACL permissions.
    public struct Permissions: OptionSet, Sendable {
        public let rawValue: acl_perm_t

        public init(rawValue: acl_perm_t) {
            self.rawValue = rawValue
        }

        /// Execute permission.
        public static let execute = Permissions(rawValue: CACL_EXECUTE)

        /// Write permission.
        public static let write = Permissions(rawValue: CACL_WRITE)

        /// Read permission.
        public static let read = Permissions(rawValue: CACL_READ)

        /// No permissions.
        public static let none: Permissions = []

        /// Read and execute (r-x).
        public static let readExecute: Permissions = [.read, .execute]

        /// Read and write (rw-).
        public static let readWrite: Permissions = [.read, .write]

        /// All permissions (rwx).
        public static let all: Permissions = [.read, .write, .execute]
    }
}

extension ACLEntry.Permissions: CustomStringConvertible {
    public var description: String {
        var s = ""
        s += contains(.read) ? "r" : "-"
        s += contains(.write) ? "w" : "-"
        s += contains(.execute) ? "x" : "-"
        return s
    }
}

// MARK: - NFSv4 Permissions

extension ACLEntry {
    /// NFSv4 ACL permissions.
    public struct NFS4Permissions: OptionSet, Sendable {
        public let rawValue: acl_perm_t

        public init(rawValue: acl_perm_t) {
            self.rawValue = rawValue
        }

        /// Read data (files) / list directory.
        public static let readData = NFS4Permissions(rawValue: CACL_READ_DATA)

        /// Write data (files) / add file to directory.
        public static let writeData = NFS4Permissions(rawValue: CACL_WRITE_DATA)

        /// Append data (files) / add subdirectory.
        public static let appendData = NFS4Permissions(rawValue: CACL_APPEND_DATA)

        /// Read named attributes.
        public static let readNamedAttrs = NFS4Permissions(rawValue: CACL_READ_NAMED_ATTRS)

        /// Write named attributes.
        public static let writeNamedAttrs = NFS4Permissions(rawValue: CACL_WRITE_NAMED_ATTRS)

        /// Execute (files) / search (directories).
        public static let execute = NFS4Permissions(rawValue: CACL_EXECUTE)

        /// Delete child entries (directories only).
        public static let deleteChild = NFS4Permissions(rawValue: CACL_DELETE_CHILD)

        /// Read basic attributes.
        public static let readAttributes = NFS4Permissions(rawValue: CACL_READ_ATTRIBUTES)

        /// Write basic attributes.
        public static let writeAttributes = NFS4Permissions(rawValue: CACL_WRITE_ATTRIBUTES)

        /// Delete the file/directory itself.
        public static let delete = NFS4Permissions(rawValue: CACL_DELETE)

        /// Read the ACL.
        public static let readACL = NFS4Permissions(rawValue: CACL_READ_ACL)

        /// Write (modify) the ACL.
        public static let writeACL = NFS4Permissions(rawValue: CACL_WRITE_ACL)

        /// Change file owner.
        public static let writeOwner = NFS4Permissions(rawValue: CACL_WRITE_OWNER)

        /// Synchronize access (for network filesystems).
        public static let synchronize = NFS4Permissions(rawValue: CACL_SYNCHRONIZE)

        /// Full control.
        public static let fullSet = NFS4Permissions(rawValue: CACL_FULL_SET)

        /// Modify (full minus ACL/owner changes).
        public static let modifySet = NFS4Permissions(rawValue: CACL_MODIFY_SET)

        /// Read set.
        public static let readSet = NFS4Permissions(rawValue: CACL_READ_SET)

        /// Write set.
        public static let writeSet = NFS4Permissions(rawValue: CACL_WRITE_SET)
    }
}

// MARK: - NFSv4 Entry Type

extension ACLEntry {
    /// NFSv4 ACL entry type.
    public enum EntryType: acl_entry_type_t, Sendable {
        /// Allow the specified permissions.
        case allow = 0x0100

        /// Deny the specified permissions.
        case deny = 0x0200

        /// Audit access (log successful access).
        case audit = 0x0400

        /// Alarm on access.
        case alarm = 0x0800
    }
}

// MARK: - NFSv4 Flags

extension ACLEntry {
    /// NFSv4 ACL inheritance flags.
    public struct Flags: OptionSet, Sendable {
        public let rawValue: acl_flag_t

        public init(rawValue: acl_flag_t) {
            self.rawValue = rawValue
        }

        /// Inherit to files.
        public static let fileInherit = Flags(rawValue: CACL_ENTRY_FILE_INHERIT)

        /// Inherit to subdirectories.
        public static let directoryInherit = Flags(rawValue: CACL_ENTRY_DIRECTORY_INHERIT)

        /// Don't propagate inheritance to grandchildren.
        public static let noPropagateInherit = Flags(rawValue: CACL_ENTRY_NO_PROPAGATE_INHERIT)

        /// Entry is inherit-only, doesn't affect this directory.
        public static let inheritOnly = Flags(rawValue: CACL_ENTRY_INHERIT_ONLY)

        /// Entry was inherited from parent.
        public static let inherited = Flags(rawValue: CACL_ENTRY_INHERITED)
    }
}

// MARK: - Text Options

extension ACL {
    /// Options for text output.
    public struct TextOptions: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Use numeric IDs instead of names.
        public static let numericIDs = TextOptions(rawValue: CACL_TEXT_NUMERIC_IDS)

        /// Append numeric ID even when name is shown.
        public static let appendID = TextOptions(rawValue: CACL_TEXT_APPEND_ID)
    }
}
