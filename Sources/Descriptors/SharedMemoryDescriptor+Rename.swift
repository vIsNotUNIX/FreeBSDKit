/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import FreeBSDKit

// MARK: - shm_rename(2) flags

/// Flags accepted by `shm_rename(2)`.
public struct ShmRenameFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Fail with `EEXIST` if the destination name is already in use.
    public static let noReplace = ShmRenameFlags(rawValue: SHM_RENAME_NOREPLACE)

    /// Atomically swap the source and destination names. Both must already
    /// exist.
    public static let exchange = ShmRenameFlags(rawValue: SHM_RENAME_EXCHANGE)
}

// MARK: - shm_rename on SharedMemoryDescriptor

public extension SharedMemoryDescriptor where Self: ~Copyable {

    /// Atomically rename a POSIX shared memory object.
    ///
    /// `shm_rename(2)` is a FreeBSD-specific operation that renames the
    /// entry in the shm namespace from `from` to `to`. By default it
    /// replaces any existing object at `to`; pass `.noReplace` to fail
    /// instead, or `.exchange` to atomically swap two existing names.
    ///
    /// - Parameters:
    ///   - from: Current shm object name.
    ///   - to: New shm object name.
    ///   - flags: Behavior flags.
    /// - Throws: `BSDError` on failure.
    static func rename(
        from: String,
        to: String,
        flags: ShmRenameFlags = []
    ) throws {
        let r = from.withCString { fromPtr in
            to.withCString { toPtr in
                Glibc.shm_rename(fromPtr, toPtr, flags.rawValue)
            }
        }
        if r != 0 {
            try BSDError.throwErrno(errno)
        }
    }
}
