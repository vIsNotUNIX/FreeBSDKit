/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Signal exit logging control.
    ///
    /// Controls whether the kernel logs when a process exits due to a signal.
    /// This is useful for debugging crash-related issues.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check logging status
    /// let status = try Procctl.LogSigExit.getStatus()
    ///
    /// // Force enable logging
    /// try Procctl.LogSigExit.forceEnable()
    /// ```
    public enum LogSigExit {
        /// Log sigexit status values.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// No forcing - use system default.
            public var isNoForce: Bool {
                rawValue == CPROCCTL_LOGSIGEXIT_CTL_NOFORCE
            }

            /// Logging is forced enabled.
            public var isForceEnabled: Bool {
                rawValue == CPROCCTL_LOGSIGEXIT_CTL_FORCE_ENABLE
            }

            /// Logging is forced disabled.
            public var isForceDisabled: Bool {
                rawValue == CPROCCTL_LOGSIGEXIT_CTL_FORCE_DISABLE
            }
        }

        /// Gets the signal exit logging status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The logging status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_LOGSIGEXIT_STATUS)
            return Status(rawValue: raw)
        }

        /// Forces signal exit logging to be enabled.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceEnable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LOGSIGEXIT_CTL, value: CPROCCTL_LOGSIGEXIT_CTL_FORCE_ENABLE)
        }

        /// Forces signal exit logging to be disabled.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func forceDisable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LOGSIGEXIT_CTL, value: CPROCCTL_LOGSIGEXIT_CTL_FORCE_DISABLE)
        }

        /// Removes forced setting, returning to system default.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func noForce(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LOGSIGEXIT_CTL, value: CPROCCTL_LOGSIGEXIT_CTL_NOFORCE)
        }
    }
}
