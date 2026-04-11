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

// MARK: - Speculative Tracing
//
// DTrace's speculation feature stages probe output in a side buffer.
// The data is only flushed to the main trace stream when a later probe
// calls `commit()` on the same speculation ID; if `discard()` is called
// instead, the staged data is dropped. This lets a script "look ahead":
// gather expensive context for every entry probe, then only keep it for
// the entries whose corresponding return probe matches some condition.
//
// The typical pattern is:
//
//     BEGIN { /* set up nothing — speculation IDs are per-thread */ }
//
//     Probe("syscall::read:entry") {
//         Assign(.thread("spec"), to: "speculation()")
//         Speculate(on: .thread("spec"))
//         Printf("entry: pid=%d", "pid")  // staged, not yet visible
//     }
//
//     Probe("syscall::read:return") {
//         When("self->spec")
//         When("arg0 < 0")          // only keep failed reads
//         CommitSpeculation(on: .thread("spec"))
//         Assign(.thread("spec"), to: "0")
//     }
//
//     Probe("syscall::read:return") {
//         When("self->spec && arg0 >= 0")
//         DiscardSpeculation(on: .thread("spec"))
//         Assign(.thread("spec"), to: "0")
//     }

// Allocating a speculation ID is just `speculation()` on the right-hand
// side of an assignment, so we don't expose a separate struct for it.
// Use `Assign(.thread("spec"), to: "speculation()")` to allocate one
// for the current thread, then refer to it via `.thread("spec")` in the
// `Speculate`/`CommitSpeculation`/`DiscardSpeculation` actions below.
//
// - Note: There is a bounded number of speculations per session
//   (`nspec`, default 1). Tune via
//   `DTraceSession.option("nspec", value: …)` if your probes overlap.

/// Routes the rest of this probe's output into a speculation buffer.
///
/// After this action runs, every subsequent printf/trace/aggregation in
/// the same probe firing is staged in the speculation buffer identified
/// by the supplied variable. The data only becomes visible to the
/// consumer if a later probe calls `CommitSpeculation` on the same
/// variable; otherwise it is dropped automatically (or by an explicit
/// `DiscardSpeculation`).
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Assign(.thread("spec"), to: "speculation()")
///     Speculate(on: .thread("spec"))
///     Printf("entry: pid=%d", "pid")
/// }
/// ```
public struct Speculate: Sendable {
    public let component: ProbeComponent

    /// - Parameter id: Variable holding the speculation ID returned by
    ///   `Speculation()`.
    public init(on id: Var) {
        self.component = ProbeComponent(kind: .action("speculate(\(id.expression));"))
    }

    /// Convenience for raw expressions (e.g. when the ID is computed
    /// inline).
    public init(rawExpression: String) {
        self.component = ProbeComponent(kind: .action("speculate(\(rawExpression));"))
    }
}

extension Speculate: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Commits a speculation buffer to the main trace stream.
///
/// Use this in a return-probe (or any later probe) once you've decided
/// the speculatively-traced data is interesting after all.
///
/// ```swift
/// Probe("syscall::read:return") {
///     When("self->spec && arg0 < 0")  // only failed reads
///     CommitSpeculation(on: .thread("spec"))
///     Assign(.thread("spec"), to: "0")
/// }
/// ```
public struct CommitSpeculation: Sendable {
    public let component: ProbeComponent

    /// - Parameter id: Variable holding the speculation ID.
    public init(on id: Var) {
        self.component = ProbeComponent(kind: .action("commit(\(id.expression));"))
    }

    /// Convenience for raw expressions.
    public init(rawExpression: String) {
        self.component = ProbeComponent(kind: .action("commit(\(rawExpression));"))
    }
}

extension CommitSpeculation: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Drops a speculation buffer without flushing it.
///
/// Use this when you've decided the staged data isn't worth keeping —
/// for instance, the matching return-probe saw a successful result and
/// you only wanted the entry context for failures.
///
/// ```swift
/// Probe("syscall::read:return") {
///     When("self->spec && arg0 >= 0")  // success → drop entry context
///     DiscardSpeculation(on: .thread("spec"))
///     Assign(.thread("spec"), to: "0")
/// }
/// ```
///
/// - Note: This is **distinct** from the unconditional `Discard()`
///   action, which throws away the trace buffer for the *current*
///   probe firing without affecting any speculation buffers.
public struct DiscardSpeculation: Sendable {
    public let component: ProbeComponent

    /// - Parameter id: Variable holding the speculation ID.
    public init(on id: Var) {
        self.component = ProbeComponent(kind: .action("discard(\(id.expression));"))
    }

    /// Convenience for raw expressions.
    public init(rawExpression: String) {
        self.component = ProbeComponent(kind: .action("discard(\(rawExpression));"))
    }
}

extension DiscardSpeculation: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
