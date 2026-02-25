/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#if arch(x86_64)
import CProcctl
import Glibc

extension Procctl {
    /// Linear address width control (x86_64 only).
    ///
    /// Controls whether the process uses 48-bit (LA48) or 57-bit (LA57)
    /// linear addresses. LA57 provides a larger address space but requires
    /// CPU and kernel support.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check current linear address width
    /// let status = try Procctl.LinearAddress.getStatus()
    /// if status.isLA57 {
    ///     print("Using 57-bit linear addresses")
    /// }
    ///
    /// // Request LA48 on next exec
    /// try Procctl.LinearAddress.setLA48OnExec()
    /// ```
    ///
    /// - Note: This is only available on x86_64 systems with LA57 CPU support.
    public enum LinearAddress {
        /// Linear address status.
        public struct Status: Sendable, Equatable {
            /// The raw status value.
            public let rawValue: Int32

            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Whether 48-bit linear addresses are in use.
            public var isLA48: Bool {
                rawValue & CPROCCTL_LA_STATUS_LA48 != 0
            }

            /// Whether 57-bit linear addresses are in use.
            public var isLA57: Bool {
                rawValue & CPROCCTL_LA_STATUS_LA57 != 0
            }
        }

        /// Gets the linear address width status.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The linear address status.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_LA_STATUS)
            return Status(rawValue: raw)
        }

        /// Sets 48-bit linear addresses on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func setLA48OnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LA_CTL, value: CPROCCTL_LA_CTL_LA48_ON_EXEC)
        }

        /// Sets 57-bit linear addresses on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func setLA57OnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LA_CTL, value: CPROCCTL_LA_CTL_LA57_ON_EXEC)
        }

        /// Uses system default linear address width on next exec.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func setDefaultOnExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_LA_CTL, value: CPROCCTL_LA_CTL_DEFAULT_ON_EXEC)
        }
    }
}
#endif
