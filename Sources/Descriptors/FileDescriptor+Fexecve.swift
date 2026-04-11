/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import FreeBSDKit

// MARK: - fexecve on FileDescriptor

public extension FileDescriptor where Self: ~Copyable {

    /// Replace the calling process with the binary referenced by this
    /// file descriptor.
    ///
    /// On success the call does not return. On failure it throws and the
    /// calling process is unchanged.
    ///
    /// See ``FreeBSDKit/fexecve(fd:argv:envp:)`` for full semantics.
    ///
    /// - Parameters:
    ///   - argv: Argument vector for the new process. Element 0 is
    ///     conventionally the program name.
    ///   - envp: Environment for the new process. Pass `nil` to inherit
    ///     the current environment.
    /// - Throws: `BSDError` describing the failure.
    func execve(argv: [String], envp: [String]? = nil) throws -> Never {
        let raw: Int32 = self.unsafe { $0 }
        try fexecve(fd: raw, argv: argv, envp: envp)
    }
}
