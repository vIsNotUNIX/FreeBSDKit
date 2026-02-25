/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Address Space Layout Randomization (ASLR) control.
    ///
    /// ASLR randomizes the memory layout of a process to make exploitation
    /// more difficult. This namespace provides control over ASLR settings
    /// for processes and their children.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check if ASLR is active
    /// let status = try Procctl.ASLR.getStatus()
    /// if status.isActive {
    ///     print("ASLR is active")
    /// }
    ///
    /// // Force enable ASLR for this process
    /// try Procctl.ASLR.forceEnable()
    /// ```
    public enum ASLR {
        /// ASLR status information.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Whether ASLR is currently active for the process.
            public var isActive: Bool {
                rawValue & CPROCCTL_ASLR_ACTIVE != 0
            }

            /// Whether ASLR is forced enabled.
            public var isForceEnabled: Bool {
                rawValue == CPROCCTL_ASLR_FORCE_ENABLE
            }

            /// Whether ASLR is forced disabled.
            public var isForceDisabled: Bool {
                rawValue == CPROCCTL_ASLR_FORCE_DISABLE
            }

            /// Whether no forcing is applied (system default).
            public var isNoForce: Bool {
                rawValue == CPROCCTL_ASLR_NOFORCE
            }
        }

        /// Gets the ASLR status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The ASLR status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_ASLR_STATUS)
            return Status(rawValue: raw)
        }

        /// Forces ASLR to be enabled for a process.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceEnable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_ASLR_CTL, value: CPROCCTL_ASLR_FORCE_ENABLE)
        }

        /// Forces ASLR to be disabled for a process.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceDisable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_ASLR_CTL, value: CPROCCTL_ASLR_FORCE_DISABLE)
        }

        /// Removes any forced ASLR setting, returning to system default.
        ///
        /// This setting takes effect on the next `execve()` call.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func noForce(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_ASLR_CTL, value: CPROCCTL_ASLR_NOFORCE)
        }
    }
}
