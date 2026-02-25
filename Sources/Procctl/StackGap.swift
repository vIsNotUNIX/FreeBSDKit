/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Stack gap randomization control.
    ///
    /// The stack gap adds a random offset between the stack and other
    /// memory regions as a security measure against stack-based exploits.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check stack gap status
    /// let status = try Procctl.StackGap.getStatus()
    /// print("Stack gap enabled: \(status.isEnabled)")
    ///
    /// // Enable stack gap
    /// try Procctl.StackGap.enable()
    /// ```
    public enum StackGap {
        /// Stack gap status information.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Whether the stack gap is enabled.
            public var isEnabled: Bool {
                (rawValue & CPROCCTL_STACKGAP_ENABLE) != 0
            }

            /// Whether stack gap will be enabled on next exec.
            public var enabledOnExec: Bool {
                (rawValue & CPROCCTL_STACKGAP_ENABLE_EXEC) != 0
            }

            /// Whether stack gap will be disabled on next exec.
            public var disabledOnExec: Bool {
                (rawValue & CPROCCTL_STACKGAP_DISABLE_EXEC) != 0
            }
        }

        /// Gets the stack gap status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The stack gap status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_STACKGAP_STATUS)
            return Status(rawValue: raw)
        }

        /// Enables the stack gap immediately.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_STACKGAP_CTL, value: CPROCCTL_STACKGAP_ENABLE)
        }

        /// Disables the stack gap immediately.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_STACKGAP_CTL, value: CPROCCTL_STACKGAP_DISABLE)
        }

        /// Enables the stack gap on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enableOnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_STACKGAP_CTL, value: CPROCCTL_STACKGAP_ENABLE_EXEC)
        }

        /// Disables the stack gap on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disableOnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_STACKGAP_CTL, value: CPROCCTL_STACKGAP_DISABLE_EXEC)
        }
    }
}
