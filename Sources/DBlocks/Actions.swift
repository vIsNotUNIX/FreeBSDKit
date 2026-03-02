/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Output Actions

/// Adds a printf action.
///
/// Prints formatted output when the probe fires.
///
/// ```swift
/// Probe("syscall::open:entry") {
///     Printf("%s[%d]: %s", "execname", "pid", "copyinstr(arg0)")
/// }
/// ```
public struct Printf: Sendable {
    public let component: ProbeComponent

    public init(_ format: String, _ args: String...) {
        let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("printf(\"\(format)\\n\"\(argList));"))
    }
}

extension Printf: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a trace action.
///
/// Traces a single value to the output buffer.
///
/// ```swift
/// Probe("syscall::read:return") {
///     Trace("arg0")
/// }
/// ```
public struct Trace: Sendable {
    public let component: ProbeComponent

    public init(_ value: String) {
        self.component = ProbeComponent(kind: .action("trace(\(value));"))
    }
}

extension Trace: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a stack trace action.
///
/// Captures a kernel or userland stack trace.
///
/// ```swift
/// Probe("fbt::malloc:entry") {
///     Stack()                    // Kernel stack
///     Stack(userland: true)      // User stack
/// }
/// ```
public struct Stack: Sendable {
    public let component: ProbeComponent

    public init(userland: Bool = false) {
        self.component = ProbeComponent(kind: .action(userland ? "ustack();" : "stack();"))
    }
}

extension Stack: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a raw D action.
///
/// Use this for actions not covered by the built-in helpers.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Action("self->ts = timestamp;")
/// }
/// Probe("syscall::read:return") {
///     When("self->ts")
///     Action("@[execname] = quantize(timestamp - self->ts);")
///     Action("self->ts = 0;")
/// }
/// ```
public struct Action: Sendable {
    public let component: ProbeComponent

    public init(_ code: String) {
        self.component = ProbeComponent(kind: .action(code))
    }
}

extension Action: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Timestamp and Latency Helpers

/// Adds a self-clearing timestamp pattern for latency measurement.
///
/// Use this at entry points to record the start time.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Timestamp()  // self->ts = timestamp;
/// }
/// ```
public struct Timestamp: Sendable {
    public let component: ProbeComponent
    public let variable: String

    public init(_ variable: String = "self->ts") {
        self.variable = variable
        self.component = ProbeComponent(kind: .action("\(variable) = timestamp;"))
    }
}

extension Timestamp: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a latency calculation action.
///
/// Use this at return points to calculate and aggregate latency.
/// Pairs with `Timestamp` at entry points.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Timestamp()
/// }
/// Probe("syscall::read:return") {
///     When("self->ts")
///     Latency(by: "execname")
/// }
/// ```
public struct Latency: Sendable {
    public let component: ProbeComponent

    public init(variable: String = "self->ts", by key: String = "execname") {
        self.component = ProbeComponent(
            kind: .action("@[\(key)] = quantize(timestamp - \(variable)); \(variable) = 0;")
        )
    }
}

extension Latency: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
