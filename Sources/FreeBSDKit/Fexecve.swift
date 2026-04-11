/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - fexecve(3)

/// Execute a binary referenced by an open file descriptor.
///
/// `fexecve(3)` is the descriptor-relative form of `execve(2)`: instead of
/// resolving a path, it runs the program backed by `fd`. This avoids a
/// path-resolution race (the process you launch is exactly the file you
/// already opened) and works in capability mode, where global namespace
/// access is forbidden but operating on existing descriptors is fine.
///
/// On success this function does not return. On failure it throws and the
/// calling process is unchanged.
///
/// - Parameters:
///   - fd: Open descriptor for an executable file. Should have been opened
///     with `O_EXEC` (or with read access on systems that allow it).
///   - argv: Argument vector. Element 0 is conventionally the program name.
///   - envp: Environment for the new process. Pass `nil` to inherit the
///     current environment unchanged.
/// - Throws: `BSDError` describing the failure (e.g. `ENOEXEC`, `EACCES`).
public func fexecve(
    fd: Int32,
    argv: [String],
    envp: [String]? = nil
) throws -> Never {
    // Materialize argv as a contiguous array of nullable C string pointers.
    let argvCStrings: [UnsafeMutablePointer<CChar>?] =
        argv.map { strdup($0) } + [nil]
    defer {
        for ptr in argvCStrings where ptr != nil { free(ptr) }
    }

    let envpCStrings: [UnsafeMutablePointer<CChar>?]?
    if let envp = envp {
        envpCStrings = envp.map { strdup($0) } + [nil]
    } else {
        envpCStrings = nil
    }
    defer {
        if let envpCStrings = envpCStrings {
            for ptr in envpCStrings where ptr != nil { free(ptr) }
        }
    }

    // Capture argv/envp pointers, then call fexecve. On success it does
    // not return; on failure we fall through to throw.
    let r: Int32 = argvCStrings.withUnsafeBufferPointer { argvBuf in
        let argvPtr = UnsafeMutablePointer(mutating: argvBuf.baseAddress!)
        if let envpCStrings = envpCStrings {
            return envpCStrings.withUnsafeBufferPointer { envpBuf in
                let envpPtr = UnsafeMutablePointer(mutating: envpBuf.baseAddress!)
                return Glibc.fexecve(fd, argvPtr, envpPtr)
            }
        } else {
            // Pass the host process's environ unchanged.
            return Glibc.fexecve(fd, argvPtr, environ)
        }
    }

    // fexecve only returns on failure.
    _ = r
    try BSDError.throwErrno(errno)
}
