/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

extension Rctl {
    /// Errors from rctl operations.
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

        /// Operation not permitted (requires root).
        public static let notPermitted = Error(errno: EPERM)

        /// No such process, user, or jail.
        public static let noSuchSubject = Error(errno: ESRCH)

        /// Invalid argument (malformed rule).
        public static let invalidArgument = Error(errno: EINVAL)

        /// Resource limits not enabled in kernel.
        public static let notSupported = Error(errno: ENOSYS)

        /// Rule already exists.
        public static let exists = Error(errno: EEXIST)

        /// No matching rules found.
        public static let notFound = Error(errno: ENOENT)

        /// Output buffer too small.
        public static let bufferTooSmall = Error(errno: ERANGE)
    }
}

extension Rctl.Error: CustomStringConvertible { }
