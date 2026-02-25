/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// No new privileges control.
    ///
    /// When enabled, this prevents a process from gaining new privileges
    /// through setuid/setgid binaries or file capabilities. The setting
    /// is inherited by all descendants.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check if no_new_privs is enabled
    /// if try Procctl.NoNewPrivileges.isEnabled() {
    ///     print("No new privileges mode active")
    /// }
    ///
    /// // Enable no_new_privs (cannot be disabled once set)
    /// try Procctl.NoNewPrivileges.enable()
    /// ```
    public enum NoNewPrivileges {
        /// Gets the no_new_privs status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: `true` if no_new_privs is enabled.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func isEnabled(
            for target: ProcessTarget = .current
        ) throws -> Bool {
            let status = try Procctl.getStatus(target, command: CPROCCTL_NO_NEW_PRIVS_STATUS)
            return status == CPROCCTL_NO_NEW_PRIVS_ENABLE
        }

        /// Enables the no_new_privs flag.
        ///
        /// Once enabled, this flag cannot be disabled. The process and all
        /// its descendants will be prevented from gaining new privileges
        /// through setuid/setgid bits or file capabilities.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_NO_NEW_PRIVS_CTL, value: CPROCCTL_NO_NEW_PRIVS_ENABLE)
        }
    }
}
