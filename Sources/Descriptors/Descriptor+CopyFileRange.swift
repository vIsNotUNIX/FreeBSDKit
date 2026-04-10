/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - copy_file_range on FileDescriptor

public extension FileDescriptor where Self: ~Copyable {

    /// Copy bytes from this file to another file using `copy_file_range(2)`.
    ///
    /// Both descriptors must refer to regular files. The destination must
    /// not be opened with `O_APPEND`. When source and destination are on the
    /// same filesystem, the kernel may use a fast path (e.g. block cloning).
    ///
    /// - Parameters:
    ///   - destination: Destination file descriptor.
    ///   - sourceOffset: If non-nil, copy starts here and the source file
    ///     offset is not advanced. If nil, the source file offset is used
    ///     and advanced.
    ///   - destinationOffset: If non-nil, write starts here and the
    ///     destination file offset is not advanced. If nil, the destination
    ///     file offset is used and advanced.
    ///   - length: Maximum number of bytes to copy.
    /// - Returns: The number of bytes copied (may be less than `length`).
    /// - Throws: `BSDError` on failure.
    func copyTo(
        _ destination: borrowing some FileDescriptor & ~Copyable,
        sourceOffset: inout off_t?,
        destinationOffset: inout off_t?,
        length: Int
    ) throws -> Int {
        try self.unsafe { srcFD in
            try destination.unsafe { dstFD in
                try copyFileRange(
                    from: srcFD,
                    inOffset: &sourceOffset,
                    to: dstFD,
                    outOffset: &destinationOffset,
                    length: length
                )
            }
        }
    }
}

// MARK: - copy_file_range on OpaqueDescriptorRef

public extension OpaqueDescriptorRef {

    /// Copy bytes from this file to another using `copy_file_range(2)`.
    ///
    /// See ``FreeBSDKit/copyFileRange(from:inOffset:to:outOffset:length:flags:)``
    /// for semantics.
    func copyTo(
        _ destination: OpaqueDescriptorRef,
        sourceOffset: inout off_t?,
        destinationOffset: inout off_t?,
        length: Int
    ) throws -> Int {
        guard let srcFD = self.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        guard let dstFD = destination.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        return try copyFileRange(
            from: srcFD,
            inOffset: &sourceOffset,
            to: dstFD,
            outOffset: &destinationOffset,
            length: length
        )
    }
}
