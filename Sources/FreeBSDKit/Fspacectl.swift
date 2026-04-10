/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - fspacectl(2)

/// Commands accepted by `fspacectl(2)`.
public struct FspacectlCommand: RawRepresentable, Sendable, Equatable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Deallocate (punch a hole in) the requested range, leaving the file
    /// size unchanged but freeing the underlying storage. Subsequent reads
    /// in the range return zeroes.
    public static let deallocate = FspacectlCommand(rawValue: SPACECTL_DEALLOC)
}

/// Result of an `fspacectl(2)` call.
public struct FspacectlResult: Sendable {
    /// Offset just past the last byte the kernel processed. For
    /// `.deallocate` this is `requestedOffset + processedBytes`.
    public let nextOffset: off_t

    /// Length of the range still left unprocessed (0 on a fully successful
    /// call).
    public let remainingLength: off_t
}

/// Perform a space-management operation on a file.
///
/// `fspacectl(2)` (FreeBSD 14+) provides hole-punching and other range-based
/// space operations on regular files. Unlike `ftruncate(2)`, the file size
/// is not changed; the requested byte range is simply deallocated.
///
/// - Parameters:
///   - fd: Open file descriptor (must be opened for writing).
///   - command: Operation to perform (currently only `.deallocate`).
///   - offset: Starting byte offset of the range.
///   - length: Length of the range, in bytes.
///   - flags: Reserved; must be 0.
/// - Returns: A `FspacectlResult` describing how much of the range the
///   kernel processed.
/// - Throws: `BSDError` on failure.
public func fspacectl(
    fd: Int32,
    command: FspacectlCommand = .deallocate,
    offset: off_t,
    length: off_t,
    flags: Int32 = 0
) throws -> FspacectlResult {
    var requested = spacectl_range(r_offset: offset, r_len: length)
    var remainder = spacectl_range(r_offset: 0, r_len: 0)

    let r = Glibc.fspacectl(fd, command.rawValue, &requested, flags, &remainder)
    if r != 0 {
        try BSDError.throwErrno(errno)
    }
    return FspacectlResult(nextOffset: remainder.r_offset, remainingLength: remainder.r_len)
}
