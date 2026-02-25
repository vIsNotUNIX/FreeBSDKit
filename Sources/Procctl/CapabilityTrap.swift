/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Capsicum capability violation trap control.
    ///
    /// When enabled, capability violations in Capsicum mode generate SIGTRAP
    /// instead of returning ENOTCAPABLE. This is useful for debugging
    /// Capsicum-enabled applications.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Enable SIGTRAP on capability violations
    /// try Procctl.CapabilityTrap.enable()
    ///
    /// // Disable trapping
    /// try Procctl.CapabilityTrap.disable()
    /// ```
    public enum CapabilityTrap {
        /// Gets the capability trap status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: `true` if capability violations will generate SIGTRAP.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func isEnabled(
            for target: ProcessTarget = .current
        ) throws -> Bool {
            let status = try Procctl.getStatus(target, command: CPROCCTL_TRAPCAP_STATUS)
            return status == CPROCCTL_TRAPCAP_CTL_ENABLE
        }

        /// Enables SIGTRAP on capability violations.
        ///
        /// When a process in capability mode attempts a disallowed operation,
        /// it will receive SIGTRAP instead of ENOTCAPABLE. This is useful
        /// for debugging with a debugger attached.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_TRAPCAP_CTL, value: CPROCCTL_TRAPCAP_CTL_ENABLE)
        }

        /// Disables SIGTRAP on capability violations.
        ///
        /// Capability violations will return ENOTCAPABLE as normal.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_TRAPCAP_CTL, value: CPROCCTL_TRAPCAP_CTL_DISABLE)
        }
    }
}
