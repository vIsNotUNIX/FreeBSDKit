/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - funlinkat on DirectoryDescriptor

public extension DirectoryDescriptor where Self: ~Copyable {

    /// Atomically remove `path` only if it still refers to `file`.
    ///
    /// `funlinkat(2)` is the TOCTOU-safe form of `unlinkat(2)`. The unlink
    /// only succeeds if the directory entry currently resolves to the same
    /// underlying file as `file`. If another process has replaced the
    /// entry, the call fails with `EDEADLK`.
    ///
    /// - Parameters:
    ///   - path: Entry to remove, relative to this directory.
    ///   - file: Open descriptor that the entry must still resolve to.
    ///   - flags: Use `.removeDir` to remove an empty directory.
    /// - Throws: `BSDError` on failure.
    func unlinkChecked(
        path: String,
        matching file: borrowing some Descriptor & ~Copyable,
        flags: AtFlags = []
    ) throws {
        try self.unsafe { dirfd in
            try file.unsafe { fileFD in
                try FreeBSDKit.funlinkat(
                    dfd: dirfd,
                    path: path,
                    fd: fileFD,
                    flags: flags.rawValue
                )
            }
        }
    }
}
