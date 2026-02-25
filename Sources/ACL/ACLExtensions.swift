/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CACL
import Glibc


extension ACL {
    /// Checks if a file has an extended ACL (beyond basic Unix permissions).
    ///
    /// - Parameter path: The file path.
    /// - Returns: `true` if the file has an extended ACL.
    public static func hasExtendedACL(path: String) -> Bool {
        return acl_extended_file_np(path) == 1
    }

    /// Checks if a symlink has an extended ACL (not following the link).
    ///
    /// - Parameter path: The symlink path.
    /// - Returns: `true` if the symlink has an extended ACL.
    public static func hasExtendedACL(linkPath path: String) -> Bool {
        return acl_extended_link_np(path) == 1
    }

    /// Validates this ACL for a specific file.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - type: The ACL type.
    /// - Returns: `true` if the ACL would be valid for this file.
    public func isValid(forPath path: String, type: ACLType = .access) -> Bool {
        guard let h = unsafeHandle else { return false }
        return acl_valid_file_np(path, type.rawValue, h) == 0
    }

    /// Validates this ACL for a specific file descriptor.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor.
    ///   - type: The ACL type.
    /// - Returns: `true` if the ACL would be valid for this file.
    public func isValid(forFD fd: Int32, type: ACLType = .access) -> Bool {
        guard let h = unsafeHandle else { return false }
        return acl_valid_fd_np(fd, type.rawValue, h) == 0
    }

    /// Compares this ACL to another for equality.
    ///
    /// - Parameter other: The other ACL to compare.
    /// - Returns: `true` if the ACLs are semantically equal.
    public func isEqual(to other: borrowing ACL) -> Bool {
        guard let h1 = unsafeHandle, let h2 = other.unsafeHandle else {
            return false
        }
        return acl_cmp_np(h1, h2) == 0
    }
}

// MARK: - Builder Pattern

extension ACL {
    /// Builder for creating ACLs programmatically.
    public struct Builder {
        private var entries: [(tag: ACLEntry.Tag, qualifier: uid_t?, permissions: ACLEntry.Permissions)]

        public init() {
            self.entries = []
        }

        /// Adds an entry for the file owner.
        public mutating func ownerPermissions(_ permissions: ACLEntry.Permissions) -> Builder {
            entries.append((.userObj, nil, permissions))
            return self
        }

        /// Adds an entry for a specific user.
        public mutating func userPermissions(_ uid: uid_t, _ permissions: ACLEntry.Permissions) -> Builder {
            entries.append((.user, uid, permissions))
            return self
        }

        /// Adds an entry for the owning group.
        public mutating func groupPermissions(_ permissions: ACLEntry.Permissions) -> Builder {
            entries.append((.groupObj, nil, permissions))
            return self
        }

        /// Adds an entry for a specific group.
        public mutating func groupPermissions(_ gid: gid_t, _ permissions: ACLEntry.Permissions) -> Builder {
            entries.append((.group, gid, permissions))
            return self
        }

        /// Adds an entry for all other users.
        public mutating func otherPermissions(_ permissions: ACLEntry.Permissions) -> Builder {
            entries.append((.other, nil, permissions))
            return self
        }

        /// Builds the ACL.
        ///
        /// - Returns: The constructed ACL.
        /// - Throws: `ACL.Error` if building fails.
        public func build() throws -> ACL {
            var acl = try ACL(count: entries.count)

            for (tag, qualifier, permissions) in entries {
                let entry = try acl.createEntry()
                try entry.setTag(tag)
                if let q = qualifier {
                    try entry.setQualifier(q)
                }
                try entry.setPermissions(permissions)
            }

            // Calculate mask if we have extended entries
            let hasExtended = entries.contains { $0.tag == .user || $0.tag == .group }
            if hasExtended {
                try acl.calculateMask()
            }

            return acl
        }
    }

    /// Creates a builder for constructing ACLs.
    public static func builder() -> Builder {
        Builder()
    }
}

// MARK: - NFSv4 Builder

extension ACL {
    /// Builder for creating NFSv4 ACLs programmatically.
    public struct NFS4Builder {
        private var entries: [(tag: ACLEntry.Tag, qualifier: uid_t?, type: ACLEntry.EntryType, permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags)]

        public init() {
            self.entries = []
        }

        /// Adds an allow entry for the file owner.
        public mutating func allowOwner(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.userObj, nil, .allow, permissions, flags))
            return self
        }

        /// Adds a deny entry for the file owner.
        public mutating func denyOwner(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.userObj, nil, .deny, permissions, flags))
            return self
        }

        /// Adds an allow entry for a specific user.
        public mutating func allowUser(_ uid: uid_t, _ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.user, uid, .allow, permissions, flags))
            return self
        }

        /// Adds a deny entry for a specific user.
        public mutating func denyUser(_ uid: uid_t, _ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.user, uid, .deny, permissions, flags))
            return self
        }

        /// Adds an allow entry for the owning group.
        public mutating func allowGroup(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.groupObj, nil, .allow, permissions, flags))
            return self
        }

        /// Adds a deny entry for the owning group.
        public mutating func denyGroup(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.groupObj, nil, .deny, permissions, flags))
            return self
        }

        /// Adds an allow entry for a specific group.
        public mutating func allowGroup(_ gid: gid_t, _ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.group, gid, .allow, permissions, flags))
            return self
        }

        /// Adds a deny entry for a specific group.
        public mutating func denyGroup(_ gid: gid_t, _ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.group, gid, .deny, permissions, flags))
            return self
        }

        /// Adds an allow entry for everyone.
        public mutating func allowEveryone(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.everyone, nil, .allow, permissions, flags))
            return self
        }

        /// Adds a deny entry for everyone.
        public mutating func denyEveryone(_ permissions: ACLEntry.NFS4Permissions, flags: ACLEntry.Flags = []) -> NFS4Builder {
            entries.append((.everyone, nil, .deny, permissions, flags))
            return self
        }

        /// Builds the NFSv4 ACL.
        ///
        /// - Returns: The constructed ACL.
        /// - Throws: `ACL.Error` if building fails.
        public func build() throws -> ACL {
            var acl = try ACL(count: entries.count)

            for (tag, qualifier, type, permissions, flags) in entries {
                let entry = try acl.createEntry()
                try entry.setTag(tag)
                if let q = qualifier {
                    try entry.setQualifier(q)
                }
                try entry.setEntryType(type)
                try entry.setNFS4Permissions(permissions)
                try entry.setFlags(flags)
            }

            return acl
        }
    }

    /// Creates a builder for constructing NFSv4 ACLs.
    public static func nfs4Builder() -> NFS4Builder {
        NFS4Builder()
    }
}
