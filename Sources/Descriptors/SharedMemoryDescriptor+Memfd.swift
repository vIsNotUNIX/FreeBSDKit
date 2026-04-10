/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import FreeBSDKit

// MARK: - memfd_create(2) flags

/// Flags for `memfd_create(2)`.
public struct MemfdFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Set the close-on-exec flag on the resulting descriptor.
    public static let closeOnExec = MemfdFlags(rawValue: UInt32(MFD_CLOEXEC))

    /// Allow file seals to be applied via `fcntl(F_ADD_SEALS, …)`.
    public static let allowSealing = MemfdFlags(rawValue: UInt32(MFD_ALLOW_SEALING))

    /// Back the object with hugetlb pages. Combine with one of the
    /// ``hugePageSize`` helpers to select a specific page size.
    public static let hugetlb = MemfdFlags(rawValue: UInt32(MFD_HUGETLB))

    /// Encode a specific hugetlb page size (a `log2(size)` value, e.g. 21
    /// for 2 MiB).
    public static func hugePageSize(log2: UInt32) -> MemfdFlags {
        MemfdFlags(rawValue: (log2 << UInt32(MFD_HUGE_SHIFT)) & UInt32(bitPattern: Int32(MFD_HUGE_MASK)))
    }
}

// MARK: - memfd_create on SharedMemoryDescriptor

public extension SharedMemoryDescriptor where Self: ~Copyable {

    /// Create an anonymous, named, in-memory file via `memfd_create(2)`.
    ///
    /// `memfd_create` returns a descriptor referencing a file that lives
    /// only in memory and has no presence in the shm namespace. Unlike
    /// ``anonymous(accessMode:flags:mode:)`` (which calls `shm_open(SHM_ANON,
    /// …)`), the returned object carries an attached debug `name` visible
    /// to tools like `procstat -v`, and can opt in to file sealing via
    /// `.allowSealing`.
    ///
    /// The `name` is for diagnostics only — it doesn't appear in any
    /// filesystem or shm namespace and need not be unique.
    ///
    /// - Parameters:
    ///   - name: Diagnostic label for the object.
    ///   - flags: Behavior flags. `closeOnExec` is set by default.
    /// - Returns: A new shared memory descriptor.
    /// - Throws: `BSDError` on failure.
    static func memfd(
        name: String,
        flags: MemfdFlags = [.closeOnExec]
    ) throws -> Self {
        let fd = name.withCString { ptr in
            Glibc.memfd_create(ptr, flags.rawValue)
        }
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(fd)
    }
}
