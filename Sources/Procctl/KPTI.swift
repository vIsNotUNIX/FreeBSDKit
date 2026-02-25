/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#if arch(x86_64)
import CProcctl
import Glibc

extension Procctl {
    /// Kernel Page Table Isolation (KPTI) control (x86_64 only).
    ///
    /// KPTI separates user-space and kernel-space page tables to mitigate
    /// Meltdown-style attacks. This control allows per-process configuration
    /// of KPTI.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check KPTI status
    /// let status = try Procctl.KPTI.getStatus()
    /// if status.isActive {
    ///     print("KPTI is active")
    /// }
    ///
    /// // Enable KPTI on next exec
    /// try Procctl.KPTI.enableOnExec()
    /// ```
    ///
    /// - Note: This is only available on x86_64 systems.
    public enum KPTI {
        /// KPTI status information.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Whether KPTI is currently active.
            public var isActive: Bool {
                rawValue & CPROCCTL_KPTI_STATUS_ACTIVE != 0
            }
        }

        /// Gets the KPTI status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The KPTI status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_KPTI_STATUS)
            return Status(rawValue: raw)
        }

        /// Enables KPTI on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enableOnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_KPTI_CTL, value: CPROCCTL_KPTI_CTL_ENABLE_ON_EXEC)
        }

        /// Disables KPTI on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disableOnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_KPTI_CTL, value: CPROCCTL_KPTI_CTL_DISABLE_ON_EXEC)
        }
    }
}
#endif
