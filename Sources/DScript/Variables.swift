/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Variable Types

/// Represents a DTrace variable reference.
///
/// DTrace supports three variable scopes:
/// - **Thread-local** (`self->name`): Per-thread storage, cleared when thread exits.
/// - **Clause-local** (`this->name`): Per-clause storage, cleared after each probe firing.
/// - **Global** (`name`): Global storage, persists across all probes.
///
/// ## Usage
///
/// ```swift
/// // Thread-local for latency tracking
/// Probe("syscall::read:entry") {
///     Assign(.thread("ts"), to: "timestamp")
/// }
/// Probe("syscall::read:return") {
///     When("self->ts")
///     Quantize("timestamp - self->ts", by: "execname")
///     Assign(.thread("ts"), to: "0")
/// }
///
/// // Clause-local for intermediate calculations
/// Probe("syscall:::entry") {
///     Assign(.clause("start"), to: "vtimestamp")
///     // ... use this->start within this clause
/// }
///
/// // Global for counters
/// BEGIN {
///     Assign(.global("total"), to: "0")
/// }
/// Probe("syscall:::entry") {
///     Assign(.global("total"), to: "total + 1")
/// }
/// ```
public enum Var: Sendable {
    /// Thread-local variable (`self->name`).
    case thread(String)

    /// Clause-local variable (`this->name`).
    case clause(String)

    /// Global variable.
    case global(String)

    /// The D expression for this variable.
    public var expression: String {
        switch self {
        case .thread(let name): return "self->\(name)"
        case .clause(let name): return "this->\(name)"
        case .global(let name): return name
        }
    }
}

// MARK: - Variable Assignment

/// Assigns a value to a variable.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Assign(.thread("ts"), to: "timestamp")
/// }
///
/// BEGIN {
///     Assign(.global("count"), to: "0")
/// }
/// ```
public struct Assign: Sendable {
    public let component: ProbeComponent

    public init(_ variable: Var, to value: String) {
        self.component = ProbeComponent(kind: .action("\(variable.expression) = \(value);"))
    }
}

extension Assign: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - String Operations

/// Copies a string from user space into a variable.
///
/// ```swift
/// Probe("syscall::open:entry") {
///     Copyinstr(from: "arg0", into: .thread("path"))
///     Printf("Opening: %s", "self->path")
/// }
/// ```
///
/// - Note: For inline use in Printf, use `copyinstr(arg0)` directly.
public struct Copyinstr: Sendable {
    public let component: ProbeComponent
    public let variable: Var

    /// Copies a user string into a variable.
    public init(from address: String, into variable: Var) {
        self.variable = variable
        self.component = ProbeComponent(kind: .action("\(variable.expression) = copyinstr(\(address));"))
    }
}

extension Copyinstr: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Converts a value to a string and stores it.
///
/// ```swift
/// Probe("syscall:::entry") {
///     Stringof("arg0", into: .thread("argstr"))
/// }
/// ```
public struct Stringof: Sendable {
    public let component: ProbeComponent

    /// Converts a value to a string and stores it.
    public init(_ value: String, into variable: Var) {
        self.component = ProbeComponent(kind: .action("\(variable.expression) = stringof(\(value));"))
    }
}

extension Stringof: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
