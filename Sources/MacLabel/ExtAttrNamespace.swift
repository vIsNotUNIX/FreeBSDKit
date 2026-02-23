/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - ExtAttr Namespace

/// FreeBSD extended attribute namespaces.
///
/// FreeBSD organizes extended attributes into namespaces. The `system`
/// namespace is used for security-related attributes that can be controlled
/// by MACF (Mandatory Access Control Framework).
///
/// ## ABI Note
/// These values correspond to FreeBSD's `sys/extattr.h`:
/// - `EXTATTR_NAMESPACE_USER` = 1
/// - `EXTATTR_NAMESPACE_SYSTEM` = 2
///
/// If FreeBSD changes these values in a future release, this enum must be updated.
///
/// ## Security Context
/// - **User namespace**: Accessible by file owner, suitable for user-level metadata
/// - **System namespace**: Restricted to privileged processes, used for MAC labels
///   and other security-critical attributes
public enum ExtAttrNamespace: Int32 {
    /// User namespace - accessible by file owner
    case user = 1  // EXTATTR_NAMESPACE_USER

    /// System namespace - used for security/MAC labels (requires privileges)
    case system = 2  // EXTATTR_NAMESPACE_SYSTEM
}
