/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import CExtendedAttributes

// MARK: - ExtAttr Namespace

/// FreeBSD extended attribute namespaces.
///
/// FreeBSD organizes extended attributes into namespaces. The `system`
/// namespace is used for security-related attributes that can be controlled
/// by MACF (Mandatory Access Control Framework).
///
/// ## ABI Note
/// These values are imported from FreeBSD's `sys/extattr.h` via the
/// CExtendedAttributes module. They will automatically match the running
/// FreeBSD version.
///
/// ## Security Context
/// - **User namespace**: Accessible by file owner, suitable for user-level metadata
/// - **System namespace**: Restricted to privileged processes, used for MAC labels
///   and other security-critical attributes
public enum ExtAttrNamespace {
    /// User namespace - accessible by file owner
    case user

    /// System namespace - used for security/MAC labels (requires privileges)
    case system

    /// Returns the FreeBSD system constant for this namespace.
    public var rawValue: Int32 {
        switch self {
        case .user:
            return CEXTATTR_NAMESPACE_USER
        case .system:
            return CEXTATTR_NAMESPACE_SYSTEM
        }
    }
}

extension ExtAttrNamespace: CustomStringConvertible {
    public var description: String {
        switch self {
        case .user:
            return "user"
        case .system:
            return "system"
        }
    }
}
