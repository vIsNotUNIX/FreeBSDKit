/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - funlinkat(2)

/// Atomically remove a directory entry only if it still refers to the
/// expected open file.
///
/// `funlinkat(2)` is a TOCTOU-safe variant of `unlinkat(2)`: it removes
/// `path` (resolved relative to `dfd`) only if `fd` refers to the same
/// underlying file. If another process has replaced the entry in the
/// meantime, the call fails with `EDEADLK` rather than unlinking the
/// wrong file.
///
/// Pass `fd = -1` to skip the equivalence check (matching `unlinkat`).
///
/// - Parameters:
///   - dfd: Directory file descriptor that `path` is resolved against.
///     Pass `AT_FDCWD` to use the current working directory.
///   - path: Entry name to remove, relative to `dfd`.
///   - fd: Open descriptor that must reference the same file as `path`,
///     or `-1` to skip the check.
///   - flags: Use `AT_REMOVEDIR` to remove an empty directory.
/// - Throws: `BSDError` on failure (notably `EDEADLK` if the entry no
///   longer refers to `fd`).
public func funlinkat(
    dfd: Int32,
    path: String,
    fd: Int32,
    flags: Int32 = 0
) throws {
    let r = path.withCString { cpath in
        Glibc.funlinkat(dfd, cpath, fd, flags)
    }
    if r != 0 {
        try BSDError.throwErrno(errno)
    }
}
