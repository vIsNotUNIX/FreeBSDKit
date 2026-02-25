/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

extension ACL {
    /// Errors from ACL operations.
    public struct Error: Swift.Error, Equatable, Sendable {
        /// The errno value from the failed operation.
        public let errno: Int32

        /// Human-readable description of the error.
        public var description: String {
            String(cString: strerror(errno))
        }

        public init(errno: Int32) {
            self.errno = errno
        }

        /// Operation not permitted.
        public static let notPermitted = Error(errno: EPERM)

        /// No such file or directory.
        public static let noSuchFile = Error(errno: ENOENT)

        /// Invalid argument.
        public static let invalidArgument = Error(errno: EINVAL)

        /// Not enough memory.
        public static let noMemory = Error(errno: ENOMEM)

        /// ACL not supported on this filesystem.
        public static let notSupported = Error(errno: EOPNOTSUPP)

        /// Too many ACL entries.
        public static let tooManyEntries = Error(errno: ENOSPC)

        /// Invalid ACL structure.
        public static let invalidACL = Error(errno: EINVAL)

        /// Read-only filesystem.
        public static let readOnlyFilesystem = Error(errno: EROFS)
    }
}

extension ACL.Error: CustomStringConvertible { }
