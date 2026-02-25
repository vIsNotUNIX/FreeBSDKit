/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Implicit PROT_MAX control.
    ///
    /// PROT_MAX limits the maximum protection that can be applied to memory
    /// mappings via `mprotect()`. When enabled, this prevents elevating
    /// permissions beyond what was specified at `mmap()` time.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check if PROT_MAX is active
    /// let status = try Procctl.ProtMax.getStatus()
    /// if status.isActive {
    ///     print("PROT_MAX protection is active")
    /// }
    ///
    /// // Force enable PROT_MAX
    /// try Procctl.ProtMax.forceEnable()
    /// ```
    public enum ProtMax {
        /// PROT_MAX status information.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Whether PROT_MAX is currently active for the process.
            public var isActive: Bool {
                rawValue & CPROCCTL_PROTMAX_ACTIVE != 0
            }

            /// Whether PROT_MAX is forced enabled.
            public var isForceEnabled: Bool {
                rawValue == CPROCCTL_PROTMAX_FORCE_ENABLE
            }

            /// Whether PROT_MAX is forced disabled.
            public var isForceDisabled: Bool {
                rawValue == CPROCCTL_PROTMAX_FORCE_DISABLE
            }

            /// Whether no forcing is applied (system default).
            public var isNoForce: Bool {
                rawValue == CPROCCTL_PROTMAX_NOFORCE
            }
        }

        /// Gets the PROT_MAX status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The PROT_MAX status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_PROTMAX_STATUS)
            return Status(rawValue: raw)
        }

        /// Forces PROT_MAX to be enabled for a process.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceEnable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_PROTMAX_CTL, value: CPROCCTL_PROTMAX_FORCE_ENABLE)
        }

        /// Forces PROT_MAX to be disabled for a process.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceDisable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_PROTMAX_CTL, value: CPROCCTL_PROTMAX_FORCE_DISABLE)
        }

        /// Removes any forced PROT_MAX setting, returning to system default.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func noForce(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_PROTMAX_CTL, value: CPROCCTL_PROTMAX_NOFORCE)
        }
    }
}
