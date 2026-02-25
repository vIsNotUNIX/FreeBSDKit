/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Out-of-memory (OOM) killer protection.
    ///
    /// This namespace provides control over the OOM killer protection flag.
    /// Protected processes are less likely to be killed when the system
    /// runs low on memory.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Protect the current process from OOM killer
    /// try Procctl.OOMProtection.protect()
    ///
    /// // Clear protection
    /// try Procctl.OOMProtection.unprotect()
    ///
    /// // Protect and have children inherit protection
    /// try Procctl.OOMProtection.protect(inherit: true)
    /// ```
    public enum OOMProtection {
        /// Protection options.
        public struct Options: OptionSet, Sendable {
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Apply protection to all descendant processes.
            public static let descend = Options(rawValue: CPROCCTL_PPROT_DESCEND)

            /// Children inherit the protection setting.
            public static let inherit = Options(rawValue: CPROCCTL_PPROT_INHERIT)

            /// Apply to descendants and have them inherit.
            public static let all: Options = [.descend, .inherit]
        }

        /// Enables OOM killer protection for a process.
        ///
        /// Protected processes are less likely to be selected by the OOM
        /// killer when memory is scarce.
        ///
        /// - Parameters:
        ///   - target: The process target (defaults to current process).
        ///   - options: Additional options (descend, inherit).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func protect(
            for target: ProcessTarget = .current,
            options: Options = []
        ) throws {
            let value = CPROCCTL_PPROT_SET | options.rawValue
            try Procctl.setControl(target, command: CPROCCTL_SPROTECT, value: value)
        }

        /// Disables OOM killer protection for a process.
        ///
        /// - Parameters:
        ///   - target: The process target (defaults to current process).
        ///   - options: Additional options (descend, inherit).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func unprotect(
            for target: ProcessTarget = .current,
            options: Options = []
        ) throws {
            let value = CPROCCTL_PPROT_CLEAR | options.rawValue
            try Procctl.setControl(target, command: CPROCCTL_SPROTECT, value: value)
        }
    }
}
