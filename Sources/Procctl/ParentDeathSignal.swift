/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Parent death signal control.
    ///
    /// Configures a signal to be sent to a process when its parent terminates.
    /// This is useful for ensuring child processes are cleaned up when their
    /// parent exits.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Set SIGTERM to be sent when parent dies
    /// try Procctl.ParentDeathSignal.set(signal: SIGTERM)
    ///
    /// // Get current parent death signal
    /// if let signal = try Procctl.ParentDeathSignal.get() {
    ///     print("Will receive signal \(signal) on parent death")
    /// }
    ///
    /// // Clear the parent death signal
    /// try Procctl.ParentDeathSignal.clear()
    /// ```
    public enum ParentDeathSignal {
        /// Gets the current parent death signal.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The signal number, or `nil` if not set.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func get(
            for target: ProcessTarget = .current
        ) throws -> Int32? {
            let signal = try Procctl.getStatus(target, command: CPROCCTL_PDEATHSIG_STATUS)
            return signal == 0 ? nil : signal
        }

        /// Sets the parent death signal.
        ///
        /// When the process's parent terminates, the specified signal will
        /// be sent to this process.
        ///
        /// - Parameters:
        ///   - signal: The signal to send (e.g., SIGTERM, SIGKILL).
        ///   - target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func set(
            signal: Int32,
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_PDEATHSIG_CTL, value: signal)
        }

        /// Clears the parent death signal.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func clear(
            for target: ProcessTarget = .current
        ) throws {
            try Procctl.setControl(target, command: CPROCCTL_PDEATHSIG_CTL, value: 0)
        }
    }
}
