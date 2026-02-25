/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import Glibc

extension Procctl {
    /// Process reaper subsystem.
    ///
    /// The reaper subsystem allows a process to "adopt" orphaned descendant
    /// processes instead of having them reparented to init (PID 1). This is
    /// useful for process supervisors and container runtimes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Become a reaper
    /// try Procctl.Reaper.acquire()
    ///
    /// // Check status
    /// let status = try Procctl.Reaper.getStatus()
    /// print("Descendants: \(status.descendantCount)")
    ///
    /// // Get list of child PIDs
    /// let pids = try Procctl.Reaper.getPids()
    ///
    /// // Kill all descendants
    /// try Procctl.Reaper.killAll(signal: SIGTERM)
    /// ```
    public enum Reaper {
        /// Status information for a reaper.
        public struct Status: Sendable {
            /// Raw status structure.
            private let raw: procctl_reaper_status

            init(raw: procctl_reaper_status) {
                self.raw = raw
            }

            /// Whether this process is a reaper.
            public var isReaper: Bool {
                raw.rs_flags & CPROCCTL_REAPER_STATUS_OWNED != 0
            }

            /// Whether this process is init (the real system reaper).
            public var isInit: Bool {
                raw.rs_flags & CPROCCTL_REAPER_STATUS_REALINIT != 0
            }

            /// Number of direct children.
            public var childCount: UInt32 {
                raw.rs_children
            }

            /// Total number of descendants.
            public var descendantCount: UInt32 {
                raw.rs_descendants
            }

            /// PID of the reaper for this process.
            public var reaperPid: pid_t {
                raw.rs_reaper
            }

            /// PID of this process.
            public var pid: pid_t {
                raw.rs_pid
            }
        }

        /// Information about a process in the reaper's tree.
        public struct PidInfo: Sendable {
            /// Raw pidinfo structure.
            private let raw: procctl_reaper_pidinfo

            init(raw: procctl_reaper_pidinfo) {
                self.raw = raw
            }

            /// The process ID.
            public var pid: pid_t {
                raw.pi_pid
            }

            /// The process's immediate subtree reaper PID.
            public var subtreePid: pid_t {
                raw.pi_subtree
            }

            /// Process flags.
            public var flags: UInt32 {
                raw.pi_flags
            }

            /// Whether this entry is valid.
            public var isValid: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_VALID != 0
            }

            /// Whether this is a direct child of the reaper.
            public var isChild: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_CHILD != 0
            }

            /// Whether this process is itself a reaper.
            public var isReaper: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_REAPER != 0
            }

            /// Whether this process is a zombie.
            public var isZombie: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_ZOMBIE != 0
            }

            /// Whether this process is stopped.
            public var isStopped: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_STOPPED != 0
            }

            /// Whether this process is exiting.
            public var isExiting: Bool {
                flags & CPROCCTL_REAPER_PIDINFO_EXITING != 0
            }
        }

        /// Result of a reaper kill operation.
        public struct KillResult: Sendable {
            /// Raw kill structure.
            private let raw: procctl_reaper_kill

            init(raw: procctl_reaper_kill) {
                self.raw = raw
            }

            /// Number of processes killed.
            public var killed: UInt32 {
                raw.rk_killed
            }

            /// PID of the first process that failed to receive signal (0 if all succeeded).
            public var failedPid: pid_t {
                raw.rk_fpid
            }
        }

        /// Acquires the reaper role for the current process.
        ///
        /// After calling this, orphaned descendants will be reparented to
        /// this process instead of init.
        ///
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func acquire() throws {
            try Procctl.call(.current, command: CPROCCTL_REAP_ACQUIRE, data: nil)
        }

        /// Releases the reaper role.
        ///
        /// Orphaned descendants will be reparented to the nearest ancestor
        /// reaper (or init).
        ///
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func release() throws {
            try Procctl.call(.current, command: CPROCCTL_REAP_RELEASE, data: nil)
        }

        /// Gets the reaper status.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: The reaper status information.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getStatus(
            for target: ProcessTarget = .current
        ) throws -> Status {
            var status = procctl_reaper_status()
            try Procctl.call(target, command: CPROCCTL_REAP_STATUS, value: &status)
            return Status(raw: status)
        }

        /// Gets information about all processes in the reaper's subtree.
        ///
        /// - Parameter target: The process target (defaults to current process).
        /// - Returns: Array of process information.
        /// - Throws: `Procctl.Error` if the operation fails.
        public static func getPids(
            for target: ProcessTarget = .current
        ) throws -> [PidInfo] {
            // First, get the count
            let status = try getStatus(for: target)
            guard status.descendantCount > 0 else {
                return []
            }

            // Allocate buffer
            let count = Int(status.descendantCount)
            let buffer = UnsafeMutablePointer<procctl_reaper_pidinfo>.allocate(capacity: count)
            defer { buffer.deallocate() }

            // Set up the request
            var pids = procctl_reaper_pids()
            pids.rp_count = status.descendantCount
            pids.rp_pids = buffer

            try Procctl.call(target, command: CPROCCTL_REAP_GETPIDS, value: &pids)

            // Convert to Swift array
            var result: [PidInfo] = []
            for i in 0..<count {
                let info = PidInfo(raw: buffer[i])
                if info.isValid {
                    result.append(info)
                }
            }
            return result
        }

        /// Kills processes in the reaper's subtree.
        ///
        /// - Parameters:
        ///   - signal: The signal to send.
        ///   - childrenOnly: If true, only kill direct children. If false, kill all descendants.
        ///   - subtreePid: If specified, only kill processes in this subtree.
        /// - Returns: Information about the kill operation.
        /// - Throws: `Procctl.Error` if the operation fails.
        @discardableResult
        public static func kill(
            signal: Int32,
            childrenOnly: Bool = false,
            subtreePid: pid_t? = nil
        ) throws -> KillResult {
            var kill = procctl_reaper_kill()
            kill.rk_sig = signal
            kill.rk_flags = childrenOnly ? CPROCCTL_REAPER_KILL_CHILDREN : CPROCCTL_REAPER_KILL_SUBTREE
            if let subtree = subtreePid {
                kill.rk_subtree = subtree
            }

            try Procctl.call(.current, command: CPROCCTL_REAP_KILL, value: &kill)
            return KillResult(raw: kill)
        }

        /// Kills all descendants with the specified signal.
        ///
        /// - Parameter signal: The signal to send (defaults to SIGKILL).
        /// - Returns: Information about the kill operation.
        /// - Throws: `Procctl.Error` if the operation fails.
        @discardableResult
        public static func killAll(signal: Int32 = SIGKILL) throws -> KillResult {
            try kill(signal: signal, childrenOnly: false)
        }

        /// Kills direct children with the specified signal.
        ///
        /// - Parameter signal: The signal to send (defaults to SIGKILL).
        /// - Returns: Information about the kill operation.
        /// - Throws: `Procctl.Error` if the operation fails.
        @discardableResult
        public static func killChildren(signal: Int32 = SIGKILL) throws -> KillResult {
            try kill(signal: signal, childrenOnly: true)
        }
    }
}
