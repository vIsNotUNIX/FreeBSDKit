/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - fspacectl on FileDescriptor

public extension FileDescriptor where Self: ~Copyable {

    /// Punch a hole in the file using `fspacectl(2)`.
    ///
    /// The file size is unchanged. Storage backing the requested range is
    /// released and subsequent reads in that range return zeros.
    ///
    /// - Parameters:
    ///   - offset: Starting byte offset of the hole.
    ///   - length: Length of the hole, in bytes.
    /// - Returns: An ``FspacectlResult`` describing how much of the range
    ///   the kernel processed.
    /// - Throws: `BSDError` on failure.
    @discardableResult
    func deallocate(offset: off_t, length: off_t) throws -> FspacectlResult {
        try self.unsafe { fd in
            try fspacectl(
                fd: fd,
                command: .deallocate,
                offset: offset,
                length: length
            )
        }
    }
}
