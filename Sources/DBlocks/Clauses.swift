/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Time Units

/// Time units supported by the DTrace profile provider.
///
/// These are used with `Tick` and `Profile` probes.
public enum DTraceTimeUnit: String, Sendable {
    case nanoseconds = "ns"
    case nanosec = "nsec"
    case microseconds = "us"
    case microsec = "usec"
    case milliseconds = "ms"
    case millisec = "msec"
    case seconds = "s"
    case sec = "sec"
    case minutes = "m"
    case min = "min"
    case hours = "h"
    case hour = "hour"
    case days = "d"
    case day = "day"
    case hertz = "hz"
}

// MARK: - Special Clauses

/// Creates a BEGIN clause that fires when the script starts.
///
/// The BEGIN clause fires once when tracing begins, before any other probes.
/// Use it to initialize variables, print headers, or set up state.
///
/// ```swift
/// let script = DBlocks {
///     BEGIN {
///         Printf("Starting trace at %Y", "walltimestamp")
///         Assign(.global("start_time"), to: "timestamp")
///     }
///
///     Probe("syscall:::entry") {
///         Count()
///     }
/// }
/// ```
public struct BEGIN: Sendable {
    private let clause: ProbeClause

    public init(@ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.clause = ProbeClause("BEGIN", builder)
    }
}

extension BEGIN: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { clause }
}

/// Creates an END clause that fires when the script exits.
///
/// The END clause fires once when tracing ends, after all other probes.
/// Use it to print final results, summaries, or cleanup.
///
/// ```swift
/// let script = DBlocks {
///     Probe("syscall:::entry") {
///         Count(by: "probefunc", into: "calls")
///     }
///
///     END {
///         Printf("Total trace time: %d ns", "timestamp - start_time")
///         Printa("calls")
///     }
/// }
/// ```
public struct END: Sendable {
    private let clause: ProbeClause

    public init(@ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.clause = ProbeClause("END", builder)
    }
}

extension END: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { clause }
}

/// Creates an ERROR clause that fires when a probe action fails.
///
/// The ERROR clause fires when a runtime error occurs in a probe action,
/// such as an illegal memory access or invalid argument.
///
/// ```swift
/// let script = DBlocks {
///     ERROR {
///         Printf("Error in %s: %s", "probefunc", "arg4")
///     }
///
///     Probe("syscall::read:entry") {
///         Printf("buf: %s", "copyinstr(arg1)")  // May fail
///     }
/// }
/// ```
public struct ERROR: Sendable {
    private let clause: ProbeClause

    public init(@ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.clause = ProbeClause("ERROR", builder)
    }
}

extension ERROR: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { clause }
}

/// Creates a Tick clause that fires on a single CPU at the specified interval.
///
/// Tick probes fire on a single CPU (potentially different each time) and are
/// useful for printing periodic status updates or partial results.
///
/// ## Time Units
///
/// Supports all DTrace time units:
/// - `.nanoseconds` / `.nanosec` / `.ns`
/// - `.microseconds` / `.microsec` / `.us`
/// - `.milliseconds` / `.millisec` / `.ms`
/// - `.seconds` / `.sec` / `.s`
/// - `.minutes` / `.min` / `.m`
/// - `.hours` / `.hour` / `.h`
/// - `.days` / `.day` / `.d`
/// - `.hertz` / `.hz` (frequency per second)
///
/// ```swift
/// let script = DBlocks {
///     Probe("syscall:::entry") {
///         Count(by: "probefunc", into: "calls")
///     }
///
///     Tick(1, .seconds) {
///         Printa("calls")
///         Clear("calls")
///     }
///
///     Tick(60, .seconds) {
///         Exit(0)
///     }
/// }
/// ```
public struct Tick: Sendable {
    private let clause: ProbeClause

    /// Creates a tick probe with the specified rate and time unit.
    ///
    /// - Parameters:
    ///   - rate: The rate value.
    ///   - unit: The time unit (default: `.hertz`).
    ///   - builder: The probe actions.
    public init(_ rate: Int, _ unit: DTraceTimeUnit = .hertz, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        let probeSpec = "tick-\(rate)\(unit.rawValue)"
        self.clause = ProbeClause(probeSpec, builder)
    }

    /// Creates a tick probe firing every N seconds.
    ///
    /// Convenience for `Tick(n, .seconds)`.
    public init(seconds n: Int, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.init(n, .seconds, builder)
    }

    /// Creates a tick probe firing at N Hz.
    ///
    /// Convenience for `Tick(n, .hertz)`.
    public init(hz n: Int, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.init(n, .hertz, builder)
    }
}

extension Tick: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { clause }
}

/// Creates a Profile clause that fires on ALL CPUs at the specified interval.
///
/// Profile probes fire on all CPUs simultaneously and are useful for
/// system-wide sampling and profiling.
///
/// The `arg0` contains the kernel PC, `arg1` contains the user PC.
/// Check these to determine if the sample was in kernel or userspace.
///
/// ```swift
/// let script = DBlocks {
///     Profile(hz: 997) {
///         When("arg0")  // Only kernel samples
///         Count(by: ["stack()"], into: "stacks")
///     }
///
///     END {
///         Printa("stacks")
///     }
/// }
/// ```
public struct Profile: Sendable {
    private let clause: ProbeClause

    /// Creates a profile probe with the specified rate and time unit.
    ///
    /// - Parameters:
    ///   - rate: The rate value.
    ///   - unit: The time unit (default: `.hertz`).
    ///   - builder: The probe actions.
    public init(_ rate: Int, _ unit: DTraceTimeUnit = .hertz, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        let probeSpec = "profile-\(rate)\(unit.rawValue)"
        self.clause = ProbeClause(probeSpec, builder)
    }

    /// Creates a profile probe firing at N Hz.
    ///
    /// Convenience for `Profile(n, .hertz)`.
    public init(hz n: Int, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.init(n, .hertz, builder)
    }

    /// Creates a profile probe firing every N seconds.
    ///
    /// Convenience for `Profile(n, .seconds)`.
    public init(seconds n: Int, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.init(n, .seconds, builder)
    }
}

extension Profile: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { clause }
}
