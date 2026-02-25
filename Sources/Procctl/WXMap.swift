/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Write XOR Execute (W^X) mapping control.
    ///
    /// Controls whether a process can have memory mappings that are both
    /// writable and executable simultaneously. Enforcing W^X is a security
    /// measure that prevents code injection attacks.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check current W^X status
    /// let status = try Procctl.WXMap.getStatus()
    /// if status.isEnforced {
    ///     print("W^X is enforced")
    /// }
    ///
    /// // Enforce W^X (disallow WX mappings)
    /// try Procctl.WXMap.enforce()
    /// ```
    public enum WXMap {
        /// W^X mapping status.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// W+X mappings are permitted.
            public var isPermitted: Bool {
                rawValue == CPROCCTL_WX_MAPPINGS_PERMIT
            }

            /// W+X mappings are disallowed, but existing ones can upgrade.
            public var isDisallowedExec: Bool {
                rawValue == CPROCCTL_WX_MAPPINGS_DISALLOW_EXEC
            }

            /// Full W^X enforcement - no simultaneous W and X.
            public var isEnforced: Bool {
                rawValue == CPROCCTL_WXORX_ENFORCE
            }
        }

        /// Gets the W^X mapping status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The W^X status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_WXMAP_STATUS)
            return Status(rawValue: raw)
        }

        /// Permits W+X mappings.
        ///
        /// This is the least restrictive setting, allowing memory to be
        /// both writable and executable.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func permit(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_WXMAP_CTL, value: CPROCCTL_WX_MAPPINGS_PERMIT)
        }

        /// Disallows W+X mappings but allows mprotect to add execute.
        ///
        /// New mappings cannot be W+X, but existing writable mappings can
        /// be made executable via mprotect.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disallowExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_WXMAP_CTL, value: CPROCCTL_WX_MAPPINGS_DISALLOW_EXEC)
        }

        /// Enforces strict W^X policy.
        ///
        /// Memory cannot be simultaneously writable and executable under
        /// any circumstances.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enforce(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_WXMAP_CTL, value: CPROCCTL_WXORX_ENFORCE)
        }
    }
}
