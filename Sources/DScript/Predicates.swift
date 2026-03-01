/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Predicate Components

/// Sets the target filter for this probe clause.
///
/// Use this to filter which processes or contexts will trigger the probe.
///
/// ```swift
/// Probe("syscall:::entry") {
///     Target(.execname("nginx"))
///     Count()
/// }
///
/// // Combine multiple conditions
/// Probe("syscall:::entry") {
///     Target(.execname("myapp") && .uid(1000))
///     Count()
/// }
/// ```
public struct Target: Sendable {
    public let component: ProbeComponent

    public init(_ target: DTraceTarget) {
        if target.predicate.isEmpty {
            // No predicate means match all - use a tautology that will be optimized out
            self.component = ProbeComponent(kind: .predicate("1"))
        } else {
            self.component = ProbeComponent(kind: .predicate(target.predicate))
        }
    }
}

extension Target: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a custom predicate condition to filter when the probe fires.
///
/// Use this for conditions not covered by `Target`, such as checking
/// argument values, return codes, or other DTrace variables.
///
/// ```swift
/// Probe("syscall:::entry") {
///     When("arg0 > 0")
///     Count()
/// }
///
/// // Check return value
/// Probe("syscall::read:return") {
///     When("arg0 > 0")  // Only successful reads
///     Sum("arg0", by: "execname")
/// }
///
/// // Combine with Target
/// Probe("syscall:::entry") {
///     Target(.execname("nginx"))
///     When("pid != 0")
///     Count()
/// }
/// ```
public struct When: Sendable {
    public let component: ProbeComponent

    public init(_ predicate: String) {
        self.component = ProbeComponent(kind: .predicate(predicate))
    }
}

extension When: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
