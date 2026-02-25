/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CProcctl
import FreeBSDKit
import Glibc

/// Swift interface to FreeBSD's procctl(2) system call.
///
/// The `Procctl` enum provides type-safe access to various process control
/// operations including security controls (ASLR, W^X), process reaping,
/// tracing controls, and more.
///
/// ## Usage
///
/// ```swift
/// // Get ASLR status for current process
/// let status = try Procctl.ASLR.getStatus()
///
/// // Disable tracing for current process
/// try Procctl.Trace.disable()
///
/// // Become a process reaper
/// try Procctl.Reaper.acquire()
/// ```
public enum Procctl {
    /// Error thrown by procctl operations.
    public struct Error: Swift.Error, Equatable, Sendable {
        /// The errno value from the failed operation.
        public let errno: Int32

        /// Human-readable description of the error.
        public var description: String {
            String(cString: strerror(errno))
        }

        public init(errno: Int32) {
            self.errno = errno
        }

        /// Operation not permitted.
        public static let notPermitted = Error(errno: EPERM)
        /// No such process.
        public static let noSuchProcess = Error(errno: ESRCH)
        /// Invalid argument.
        public static let invalidArgument = Error(errno: EINVAL)
        /// Operation not supported.
        public static let notSupported = Error(errno: EOPNOTSUPP)
        /// Resource busy.
        public static let busy = Error(errno: EBUSY)
    }
}

/// Target specification for procctl operations.
///
/// Specifies which process(es) to target for a procctl operation.
public struct ProcessTarget: Sendable {
    /// The target type.
    public let idType: idtype_t
    /// The target ID.
    public let id: id_t

    /// Creates a target for a specific process.
    ///
    /// - Parameter pid: The process ID.
    public static func pid(_ pid: pid_t) -> ProcessTarget {
        ProcessTarget(idType: CPROCCTL_P_PID, id: id_t(pid))
    }

    /// Creates a target for a process group.
    ///
    /// - Parameter pgid: The process group ID.
    public static func processGroup(_ pgid: pid_t) -> ProcessTarget {
        ProcessTarget(idType: CPROCCTL_P_PGID, id: id_t(pgid))
    }

    /// Target the current process.
    public static let current = ProcessTarget(idType: CPROCCTL_P_PID, id: 0)
}

// MARK: - Internal Helpers

extension Procctl {
    /// Calls procctl and throws on error.
    @inline(__always)
    static func call(
        _ target: ProcessTarget,
        command: Int32,
        data: UnsafeMutableRawPointer?
    ) throws {
        let result = cprocctl_call(target.idType, target.id, command, data)
        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Calls procctl with an inout value.
    @inline(__always)
    static func call<T>(
        _ target: ProcessTarget,
        command: Int32,
        value: inout T
    ) throws {
        try withUnsafeMutablePointer(to: &value) { ptr in
            try call(target, command: command, data: ptr)
        }
    }

    /// Gets an Int32 status value.
    @inline(__always)
    static func getStatus(
        _ target: ProcessTarget,
        command: Int32
    ) throws -> Int32 {
        var status: Int32 = 0
        try call(target, command: command, value: &status)
        return status
    }

    /// Sets an Int32 control value.
    @inline(__always)
    static func setControl(
        _ target: ProcessTarget,
        command: Int32,
        value: Int32
    ) throws {
        var val = value
        try call(target, command: command, value: &val)
    }
}
