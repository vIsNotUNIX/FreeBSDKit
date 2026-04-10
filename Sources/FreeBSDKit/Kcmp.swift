/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - Kcmp comparison type

/// Kind of kernel object to compare with `kcmp(2)`.
public struct KcmpType: RawRepresentable, Sendable, Equatable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Compare two file descriptions referred to by file descriptors. Two
    /// descriptors that share the same description (e.g. one was produced
    /// by `dup(2)` of the other) compare equal.
    public static let file = KcmpType(rawValue: KCMP_FILE)

    /// "Deep" comparison: tests whether the underlying kernel object
    /// (e.g. vnode) backing two file descriptions is the same. Two
    /// independent `open(2)`s of the same path compare equal under this
    /// type but not under `.file`.
    public static let fileObject = KcmpType(rawValue: KCMP_FILEOBJ)

    /// Whether two processes share a file-descriptor table. The `idx`
    /// arguments are ignored for this type.
    public static let files = KcmpType(rawValue: KCMP_FILES)

    /// Whether two processes share a signal-handler table. The `idx`
    /// arguments are ignored.
    public static let sighand = KcmpType(rawValue: KCMP_SIGHAND)

    /// Whether two processes share a virtual-memory address space. The
    /// `idx` arguments are ignored.
    public static let vm = KcmpType(rawValue: KCMP_VM)
}

// MARK: - Kcmp result

/// Result of a `kcmp(2)` comparison.
public enum KcmpOrdering: Sendable, Equatable {
    /// The two objects are the same.
    case equal
    /// The first object sorts before the second in the kernel's stable
    /// internal ordering.
    case less
    /// The first object sorts after the second.
    case greater
    /// The objects cannot be compared (e.g. `KCMP_FILEOBJ` on a socket
    /// and a regular file).
    case incomparable
}

// MARK: - kcmp(2)

/// Compare two kernel objects referenced from (possibly different) processes.
///
/// `kcmp(2)` exposes the kernel's identity test for objects backing file
/// descriptors and per-process tables. It is the standard way to determine
/// whether two descriptors — possibly held by different processes — refer
/// to the same underlying kernel object, and whether two processes share
/// resources like the file-descriptor table or VM space.
///
/// The kernel imposes a stable internal ordering on objects, so the result
/// is tri-valued (`equal`/`less`/`greater`) plus an `incomparable` case
/// for object kinds that cannot be ordered.
///
/// The caller must have permission to debug both target processes.
///
/// - Parameters:
///   - pid1: First process. Use `getpid()` for the calling process.
///   - pid2: Second process.
///   - type: Kind of object to compare.
///   - idx1: First object identifier (typically a file descriptor in
///     `pid1`'s table). Ignored for `.files`/`.sighand`/`.vm`.
///   - idx2: Second object identifier (typically a file descriptor in
///     `pid2`'s table). Ignored for `.files`/`.sighand`/`.vm`.
/// - Returns: A ``KcmpOrdering`` describing the relationship.
/// - Throws: `BSDError` on failure.
public func kcmp(
    pid1: pid_t,
    pid2: pid_t,
    type: KcmpType,
    idx1: UInt = 0,
    idx2: UInt = 0
) throws -> KcmpOrdering {
    let r = Glibc.kcmp(pid1, pid2, type.rawValue, uintptr_t(idx1), uintptr_t(idx2))
    switch r {
    case 0:  return .equal
    case 1:  return .less
    case 2:  return .greater
    case 3:  return .incomparable
    case -1: try BSDError.throwErrno(errno)
    default:
        // The kernel currently only documents 0..3, but be defensive about
        // future return codes.
        throw BSDError.errno(EINVAL)
    }
}
