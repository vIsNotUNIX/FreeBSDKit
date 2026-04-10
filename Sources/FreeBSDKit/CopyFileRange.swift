/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - copy_file_range(2)

/// Copy a byte range from one file to another in the kernel.
///
/// `copy_file_range(2)` performs an in-kernel copy from `inFD` to `outFD`,
/// potentially using a filesystem-specific fast path (e.g. block cloning on
/// ZFS) when both descriptors live on the same filesystem. This is a regular-
/// file analogue of `sendfile(2)` and avoids the user-space round trip of a
/// `read`/`write` loop.
///
/// - Parameters:
///   - inFD: Source file descriptor (must be opened for reading).
///   - inOffset: If non-nil, copy starts at this offset and the source file
///     offset is not modified. If nil, copying starts at the source file
///     offset and that offset is advanced.
///   - outFD: Destination file descriptor (must be opened for writing and
///     not have `O_APPEND` set).
///   - outOffset: If non-nil, write begins at this offset and the destination
///     file offset is not modified. If nil, writing begins at the destination
///     file offset and that offset is advanced.
///   - length: Maximum number of bytes to copy.
///   - flags: Reserved; must be 0.
/// - Returns: Number of bytes actually copied. May be less than `length`
///   on short copies, including 0 at end-of-file.
/// - Throws: `BSDError` on failure.
public func copyFileRange(
    from inFD: Int32,
    inOffset: inout off_t?,
    to outFD: Int32,
    outOffset: inout off_t?,
    length: Int,
    flags: UInt32 = 0
) throws -> Int {
    // Materialize the optional offsets into stack storage so we can pass
    // a pointer (or nil) to the syscall.
    var inOff = inOffset ?? 0
    var outOff = outOffset ?? 0
    let inPtr: UnsafeMutablePointer<off_t>? = (inOffset != nil) ? withUnsafeMutablePointer(to: &inOff) { $0 } : nil
    let outPtr: UnsafeMutablePointer<off_t>? = (outOffset != nil) ? withUnsafeMutablePointer(to: &outOff) { $0 } : nil

    let n = Glibc.copy_file_range(inFD, inPtr, outFD, outPtr, length, flags)
    if n < 0 {
        try BSDError.throwErrno(errno)
    }

    if inOffset != nil { inOffset = inOff }
    if outOffset != nil { outOffset = outOff }
    return n
}
