/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CJails

/// Flags controlling `jail_set(2)` behavior.
///
/// This type is a Swift wrapper around the `JAIL_*` flag constants used by
/// `jail_set(2)`. Multiple flags may be combined.
///
/// These flags affect how a jail is created, updated, or associated with a
/// jail descriptor.
///
/// - Note: The underlying raw values are part of the FreeBSD jail ABI and
///   must not be changed.
/// - SeeAlso: `jail_set(2)`
public struct JailSetFlags: OptionSet, Sendable {

    /// The raw C bitmask value passed to `jail_set(2)`.
    public let rawValue: Int32

    /// Creates a flag set from a raw C bitmask.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Create a new jail.
    public static let create = JailSetFlags(rawValue: JAIL_CREATE)

    /// Update an existing jail.
    public static let update = JailSetFlags(rawValue: JAIL_UPDATE)

    /// Attach the calling process to the jail.
    public static let attach = JailSetFlags(rawValue: JAIL_ATTACH)

    /// Use a jail descriptor supplied in the parameter list.
    public static let useDesc = JailSetFlags(rawValue: JAIL_USE_DESC)

    /// Operate relative to a jail descriptor.
    public static let atDesc = JailSetFlags(rawValue: JAIL_AT_DESC)

    /// Request that a jail descriptor be returned.
    public static let getDesc = JailSetFlags(rawValue: JAIL_GET_DESC)

    /// Take ownership of a returned jail descriptor.
    public static let ownDesc = JailSetFlags(rawValue: JAIL_OWN_DESC)
}

/// Flags controlling `jail_get(2)` behavior.
///
/// This type is a Swift wrapper around the `JAIL_*` flag constants used by
/// `jail_get(2)`. Multiple flags may be combined.
///
/// These flags control how jail information is queried and whether a jail
/// descriptor is returned.
///
/// - Note: The underlying raw values are part of the FreeBSD jail ABI and
///   must not be changed.
/// - SeeAlso: `jail_get(2)`
public struct JailGetFlags: OptionSet, Sendable {

    /// The raw C bitmask value passed to `jail_get(2)`.
    public let rawValue: Int32

    /// Creates a flag set from a raw C bitmask.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Match jails that are in the process of dying.
    public static let dying = JailGetFlags(rawValue: JAIL_DYING)

    /// Use a jail descriptor supplied in the parameter list.
    public static let useDesc = JailGetFlags(rawValue: JAIL_USE_DESC)

    /// Operate relative to a jail descriptor.
    public static let atDesc = JailGetFlags(rawValue: JAIL_AT_DESC)

    /// Request that a jail descriptor be returned.
    public static let getDesc = JailGetFlags(rawValue: JAIL_GET_DESC)

    /// Take ownership of a returned jail descriptor.
    public static let ownDesc = JailGetFlags(rawValue: JAIL_OWN_DESC)
}