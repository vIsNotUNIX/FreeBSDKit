/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import CExterr

// MARK: - Aux entry kinds

/// A single ELF auxiliary-vector entry kind, for use with
/// ``ElfAuxInfo``.
///
/// Mirrors the `AT_*` constants from `<sys/elf_common.h>`. **Only** the
/// entries listed here are actually accessible via `elf_aux_info(3)` on
/// FreeBSD — the manpage documents the full set, and most `AT_*` values
/// from the auxv are intentionally not exposed.
public struct ElfAuxKind: RawRepresentable, Sendable, Equatable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Page size in bytes (`int`).
    public static let pageSize    = ElfAuxKind(rawValue: AT_PAGESZ)
    /// Path the kernel actually used to load this binary (string).
    /// May be unavailable if the process was started via `fexecve(2)`
    /// and the name cache no longer holds an entry.
    public static let execPath    = ElfAuxKind(rawValue: AT_EXECPATH)
    /// FreeBSD `__FreeBSD_version` of the kernel/jail (`int`).
    public static let osReldate   = ElfAuxKind(rawValue: AT_OSRELDATE)
    /// Number of CPUs visible to the process (`int`).
    public static let ncpus       = ElfAuxKind(rawValue: AT_NCPUS)
    /// Primary CPU feature flags (`u_long`, machine-dependent).
    public static let hwcap       = ElfAuxKind(rawValue: AT_HWCAP)
    /// Secondary CPU feature flags (`u_long`).
    public static let hwcap2      = ElfAuxKind(rawValue: AT_HWCAP2)
    /// Tertiary CPU feature flags (`u_long`).
    public static let hwcap3      = ElfAuxKind(rawValue: AT_HWCAP3)
    /// Quaternary CPU feature flags (`u_long`).
    public static let hwcap4      = ElfAuxKind(rawValue: AT_HWCAP4)
}

// MARK: - elf_aux_info(3)

/// Query entries from the ELF auxiliary vector handed to this process by
/// the kernel.
///
/// `elf_aux_info(3)` is the FreeBSD-blessed way to read the auxv at
/// runtime. The native call accepts a buffer whose size **must** match
/// the kernel's expected size for the specific entry kind, so this
/// wrapper offers separately-typed entry points (`int32`, `unsignedLong`,
/// `string`) corresponding to the documented categories.
public enum ElfAuxInfo {

    /// Query an aux entry that the kernel reports as a 32-bit `int`.
    ///
    /// Used for `.pageSize`, `.ncpus`, `.osReldate`.
    ///
    /// - Parameter kind: The entry kind to query.
    /// - Returns: The value, or `nil` if the kernel did not provide an
    ///   entry of this kind (`ENOENT`).
    /// - Throws: `BSDError` on failure.
    public static func int32(_ kind: ElfAuxKind) throws -> Int32? {
        var value: Int32 = 0
        let r = withUnsafeMutablePointer(to: &value) { ptr -> Int32 in
            CExterr.elf_aux_info(kind.rawValue, ptr, Int32(MemoryLayout<Int32>.size))
        }
        if r != 0 {
            if r == ENOENT { return nil }
            try BSDError.throwErrno(r)
        }
        return value
    }

    /// Query an aux entry that the kernel reports as an `unsigned long`.
    ///
    /// Used for the `.hwcap` family.
    ///
    /// - Parameter kind: The entry kind to query.
    /// - Returns: The value, or `nil` if the kernel did not provide an
    ///   entry of this kind (`ENOENT`).
    /// - Throws: `BSDError` on failure.
    public static func unsignedLong(_ kind: ElfAuxKind) throws -> UInt? {
        var value: UInt = 0
        let r = withUnsafeMutablePointer(to: &value) { ptr -> Int32 in
            CExterr.elf_aux_info(kind.rawValue, ptr, Int32(MemoryLayout<UInt>.size))
        }
        if r != 0 {
            if r == ENOENT { return nil }
            try BSDError.throwErrno(r)
        }
        return value
    }

    /// Query an aux entry that the kernel reports as a NUL-terminated
    /// string.
    ///
    /// Used for `.execPath`. May return `nil` for `.execPath` if the
    /// process was started via `fexecve(2)` and the kernel no longer
    /// has a cached name for the binary.
    ///
    /// - Parameters:
    ///   - kind: The entry kind to query.
    ///   - bufferSize: Size of the temporary buffer to use.
    ///     `MAXPATHLEN` is the safe default for path-shaped entries.
    /// - Returns: The string value, or `nil` if the kernel did not
    ///   provide an entry of this kind.
    /// - Throws: `BSDError` on failure.
    public static func string(
        _ kind: ElfAuxKind,
        bufferSize: Int = Int(PATH_MAX)
    ) throws -> String? {
        guard bufferSize > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: bufferSize)
        let r = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            CExterr.elf_aux_info(kind.rawValue, ptr.baseAddress, Int32(ptr.count))
        }
        if r != 0 {
            if r == ENOENT { return nil }
            try BSDError.throwErrno(r)
        }
        let length = buf.firstIndex(of: 0) ?? buf.count
        let bytes = buf.prefix(length).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
