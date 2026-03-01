/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Control Actions

/// Exits the DTrace program.
///
/// ```swift
/// Tick(60, .seconds) {
///     Exit(0)  // Exit after 60 seconds
/// }
///
/// // Exit on error condition
/// Probe("syscall::read:return") {
///     When("arg0 < 0")
///     Exit(1)
/// }
/// ```
public struct Exit: Sendable {
    public let component: ProbeComponent

    /// Exits with the specified status code.
    public init(_ status: Int = 0) {
        self.component = ProbeComponent(kind: .action("exit(\(status));"))
    }
}

extension Exit: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Stops tracing without exiting (useful for one-shot scripts).
///
/// The tracing session remains open but no more probes fire.
public struct Stop: Sendable {
    public let component: ProbeComponent

    public init() {
        self.component = ProbeComponent(kind: .action("stop();"))
    }
}

extension Stop: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Aggregation Operations

/// Prints aggregation data.
///
/// When used without arguments, prints all aggregations.
/// When given a name, prints only that aggregation.
///
/// ```swift
/// Tick(1, .seconds) {
///     Printa()           // Print all aggregations
///     Printa("calls")    // Print specific aggregation
/// }
///
/// // With custom format
/// END {
///     Printa("%s: %@count\n", "calls")
/// }
/// ```
public struct Printa: Sendable {
    public let component: ProbeComponent

    /// Prints all aggregations.
    public init() {
        self.component = ProbeComponent(kind: .action("printa(@);"))
    }

    /// Prints a specific named aggregation.
    public init(_ name: String) {
        self.component = ProbeComponent(kind: .action("printa(@\(name));"))
    }

    /// Prints a named aggregation with a custom format.
    ///
    /// ```swift
    /// Printa("%s: %@count\n", "calls")
    /// ```
    public init(_ format: String, _ name: String) {
        self.component = ProbeComponent(kind: .action("printa(\"\(format)\", @\(name));"))
    }
}

extension Printa: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Clears aggregation data.
///
/// ```swift
/// Tick(1, .seconds) {
///     Printa("calls")
///     Clear("calls")  // Reset after printing
/// }
/// ```
public struct Clear: Sendable {
    public let component: ProbeComponent

    /// Clears all aggregations.
    public init() {
        self.component = ProbeComponent(kind: .action("clear(@);"))
    }

    /// Clears a specific named aggregation.
    public init(_ name: String) {
        self.component = ProbeComponent(kind: .action("clear(@\(name));"))
    }
}

extension Clear: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Truncates aggregation data to the top N entries.
///
/// ```swift
/// END {
///     Trunc("calls", 10)  // Keep only top 10
///     Printa("calls")
/// }
/// ```
public struct Trunc: Sendable {
    public let component: ProbeComponent

    /// Truncates all aggregations to N entries.
    public init(_ n: Int) {
        self.component = ProbeComponent(kind: .action("trunc(@, \(n));"))
    }

    /// Truncates a specific aggregation to N entries.
    public init(_ name: String, _ n: Int) {
        self.component = ProbeComponent(kind: .action("trunc(@\(name), \(n));"))
    }

    /// Clears a specific aggregation entirely (n = 0).
    public init(_ name: String) {
        self.component = ProbeComponent(kind: .action("trunc(@\(name));"))
    }
}

extension Trunc: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Normalizes aggregation data by a factor.
///
/// Useful for converting units (e.g., nanoseconds to milliseconds).
///
/// ```swift
/// END {
///     Normalize("latency", 1_000_000)  // ns -> ms
///     Printa("latency")
/// }
/// ```
public struct Normalize: Sendable {
    public let component: ProbeComponent

    /// Normalizes a specific aggregation by a factor.
    public init(_ name: String, _ factor: Int) {
        self.component = ProbeComponent(kind: .action("normalize(@\(name), \(factor));"))
    }
}

extension Normalize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Denormalizes aggregation data (reverses normalization).
public struct Denormalize: Sendable {
    public let component: ProbeComponent

    /// Denormalizes a specific aggregation.
    public init(_ name: String) {
        self.component = ProbeComponent(kind: .action("denormalize(@\(name));"))
    }
}

extension Denormalize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
