/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

extension Cpuset {
    /// Errors from cpuset operations.
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

        /// Operation not permitted (requires root for some operations).
        public static let notPermitted = Error(errno: EPERM)

        /// No such process, thread, or jail.
        public static let noSuchProcess = Error(errno: ESRCH)

        /// Invalid argument (invalid CPU number, etc.).
        public static let invalidArgument = Error(errno: EINVAL)

        /// Cpuset not found.
        public static let notFound = Error(errno: ENOENT)

        /// Cannot allocate memory.
        public static let noMemory = Error(errno: ENOMEM)

        /// Output buffer too small.
        public static let bufferTooSmall = Error(errno: ERANGE)

        /// Cpuset would become empty.
        public static let wouldBeEmpty = Error(errno: EDEADLK)
    }
}

extension Cpuset.Error: CustomStringConvertible { }
