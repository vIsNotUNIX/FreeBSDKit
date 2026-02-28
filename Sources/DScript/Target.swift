/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

/// Specifies what process(es) or context to trace.
///
/// Use `DTraceTarget` to filter DTrace output to specific processes,
/// executables, or modules rather than tracing system-wide.
///
/// ## Examples
///
/// ```swift
/// // Trace a specific process
/// .pid(1234)
///
/// // Trace all processes with a given name
/// .execname("nginx")
///
/// // Trace the current process
/// .currentProcess
///
/// // Combine conditions
/// .execname("myapp") && .uid(1000)
/// ```
public struct DTraceTarget: Sendable, Hashable {
    /// The predicate expression for D scripts.
    public let predicate: String

    private init(predicate: String) {
        self.predicate = predicate
    }

    // MARK: - Factory Methods

    /// Traces all processes (no filtering).
    public static let all = DTraceTarget(predicate: "")

    /// Traces only the current process.
    public static var currentProcess: DTraceTarget {
        .pid(getpid())
    }

    /// Traces a specific process by PID.
    public static func pid(_ pid: pid_t) -> DTraceTarget {
        DTraceTarget(predicate: "pid == \(pid)")
    }

    /// Traces processes with a specific executable name.
    public static func execname(_ name: String) -> DTraceTarget {
        DTraceTarget(predicate: "execname == \"\(name)\"")
    }

    /// Traces processes where name contains the pattern.
    public static func processNameContains(_ pattern: String) -> DTraceTarget {
        DTraceTarget(predicate: "strstr(execname, \"\(pattern)\") != NULL")
    }

    /// Traces processes owned by a specific user ID.
    public static func uid(_ uid: uid_t) -> DTraceTarget {
        DTraceTarget(predicate: "uid == \(uid)")
    }

    /// Traces processes owned by a specific group ID.
    public static func gid(_ gid: gid_t) -> DTraceTarget {
        DTraceTarget(predicate: "gid == \(gid)")
    }

    /// Traces processes in a specific jail.
    public static func jail(_ jid: Int32) -> DTraceTarget {
        DTraceTarget(predicate: "jid == \(jid)")
    }

    /// Traces based on a custom D predicate expression.
    public static func custom(_ expression: String) -> DTraceTarget {
        DTraceTarget(predicate: expression)
    }

    // MARK: - Combining Targets

    /// Combines this target with another using AND logic.
    public func and(_ other: DTraceTarget) -> DTraceTarget {
        if predicate.isEmpty { return other }
        if other.predicate.isEmpty { return self }
        return DTraceTarget(predicate: "(\(predicate)) && (\(other.predicate))")
    }

    /// Combines this target with another using OR logic.
    public func or(_ other: DTraceTarget) -> DTraceTarget {
        if predicate.isEmpty || other.predicate.isEmpty { return .all }
        return DTraceTarget(predicate: "(\(predicate)) || (\(other.predicate))")
    }

    /// Negates this target.
    public func negated() -> DTraceTarget {
        if predicate.isEmpty { return self }
        return DTraceTarget(predicate: "!(\(predicate))")
    }
}

extension DTraceTarget: CustomStringConvertible {
    public var description: String {
        predicate.isEmpty ? "(all)" : "/\(predicate)/"
    }
}

// MARK: - Operators

extension DTraceTarget {
    public static func && (lhs: DTraceTarget, rhs: DTraceTarget) -> DTraceTarget {
        lhs.and(rhs)
    }

    public static func || (lhs: DTraceTarget, rhs: DTraceTarget) -> DTraceTarget {
        lhs.or(rhs)
    }

    public static prefix func ! (target: DTraceTarget) -> DTraceTarget {
        target.negated()
    }
}
