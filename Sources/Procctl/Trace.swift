/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Process tracing (ptrace/debugger) control.
    ///
    /// This namespace provides control over whether a process can be traced
    /// by debuggers like gdb, lldb, or ktrace. Disabling tracing can improve
    /// security for sensitive applications.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Check if tracing is enabled
    /// if try Procctl.Trace.isEnabled() {
    ///     // Disable tracing permanently
    ///     try Procctl.Trace.disable()
    /// }
    /// ```
    public enum Trace {
        /// Trace control values.
        public enum Control: Int32, Sendable {
            /// Enable tracing (default state).
            case enable = 1
            /// Disable tracing permanently.
            case disable = 2
            /// Disable tracing, but re-enable on exec.
            case disableExec = 3
        }

        /// Gets the trace status for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The current trace control setting.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Control {
            let raw = try Procctl.getStatus(target, command: CPROCCTL_TRACE_STATUS)
            return Control(rawValue: raw) ?? .enable
        }

        /// Checks if tracing is currently enabled.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: `true` if tracing is enabled.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func isEnabled(
            for target: ProcessTarget = .current
        ) throws -> Bool {
            let status = try getStatus(for: target)
            return status == .enable
        }

        /// Enables tracing for a process.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func enable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_TRACE_CTL, value: CPROCCTL_TRACE_CTL_ENABLE)
        }

        /// Disables tracing for a process permanently.
        ///
        /// Once disabled, tracing cannot be re-enabled.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disable(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_TRACE_CTL, value: CPROCCTL_TRACE_CTL_DISABLE)
        }

        /// Disables tracing until the next exec.
        ///
        /// Tracing will be re-enabled after the process calls `execve()`.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func disableUntilExec(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_TRACE_CTL, value: CPROCCTL_TRACE_CTL_DISABLE_EXEC)
        }
    }
}
