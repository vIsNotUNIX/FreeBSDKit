/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Probe Clause Builder

/// A result builder for constructing the contents of a probe clause.
@resultBuilder
public struct ProbeClauseBuilder {
    public static func buildBlock(_ components: [ProbeComponent]...) -> [ProbeComponent] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[ProbeComponent]]) -> [ProbeComponent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [ProbeComponent]?) -> [ProbeComponent] {
        component ?? []
    }

    public static func buildEither(first component: [ProbeComponent]) -> [ProbeComponent] {
        component
    }

    public static func buildEither(second component: [ProbeComponent]) -> [ProbeComponent] {
        component
    }
}

// MARK: - Probe Clause

/// A single probe clause in a DTrace script.
///
/// Each clause consists of a probe specification, optional predicates,
/// and one or more actions.
///
/// ## Creating Clauses
///
/// Use the result builder syntax:
/// ```swift
/// let clause = Probe("syscall:::entry") {
///     Target(.execname("nginx"))
///     Count(by: "probefunc")
/// }
/// ```
///
/// Or build programmatically:
/// ```swift
/// var clause = ProbeClause(probe: "syscall:::entry")
/// clause.add(action: "@ = count();")
/// clause.add(predicate: "execname == \"nginx\"")
/// ```
public struct ProbeClause: Sendable {
    public let probe: String
    public private(set) var predicates: [String]
    public private(set) var actions: [String]

    public init(_ probe: String, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.probe = probe
        let components = builder()

        var predicates: [String] = []
        var actions: [String] = []

        for component in components {
            switch component.kind {
            case .predicate(let pred):
                predicates.append(pred)
            case .action(let act):
                actions.append(act)
            }
        }

        self.predicates = predicates
        self.actions = actions
    }

    /// Creates a probe clause with explicit components (for programmatic use).
    public init(probe: String, predicates: [String] = [], actions: [String] = []) {
        self.probe = probe
        self.predicates = predicates
        self.actions = actions
    }

    // MARK: - Composing Clauses

    /// Adds a raw action string to this clause.
    ///
    /// ```swift
    /// var clause = ProbeClause(probe: "syscall:::entry")
    /// clause.add(action: "@[probefunc] = count();")
    /// ```
    public mutating func add(action: String) {
        actions.append(action)
    }

    /// Adds an action component to this clause.
    ///
    /// ```swift
    /// var clause = ProbeClause(probe: "syscall:::entry")
    /// clause.add(Count(by: "probefunc"))
    /// ```
    public mutating func add<T: ProbeComponentConvertible>(_ component: T) {
        let probeComponent = component.asProbeComponent()
        switch probeComponent.kind {
        case .predicate(let pred):
            predicates.append(pred)
        case .action(let act):
            actions.append(act)
        }
    }

    /// Adds a raw predicate string to this clause.
    ///
    /// ```swift
    /// var clause = ProbeClause(probe: "syscall:::entry")
    /// clause.add(predicate: "execname == \"nginx\"")
    /// ```
    public mutating func add(predicate: String) {
        predicates.append(predicate)
    }

    /// Adds a target predicate to this clause.
    ///
    /// ```swift
    /// var clause = ProbeClause(probe: "syscall:::entry")
    /// clause.add(target: .execname("nginx"))
    /// ```
    public mutating func add(target: DTraceTarget) {
        if !target.predicate.isEmpty {
            predicates.append(target.predicate)
        }
    }

    /// Returns a new clause with the given action added.
    ///
    /// ```swift
    /// let clause = Probe("syscall:::entry") { Count() }
    /// let extended = clause.adding(action: "printf(\"hit\\n\");")
    /// ```
    public func adding(action: String) -> ProbeClause {
        ProbeClause(probe: probe, predicates: predicates, actions: actions + [action])
    }

    /// Returns a new clause with the given component added.
    ///
    /// ```swift
    /// let clause = Probe("syscall:::entry") { Count() }
    /// let extended = clause.adding(Printf("fired!"))
    /// ```
    public func adding<T: ProbeComponentConvertible>(_ component: T) -> ProbeClause {
        var copy = self
        copy.add(component)
        return copy
    }

    /// Returns a new clause with the given predicate added.
    ///
    /// ```swift
    /// let clause = Probe("syscall:::entry") { Count() }
    /// let filtered = clause.adding(predicate: "arg0 > 0")
    /// ```
    public func adding(predicate: String) -> ProbeClause {
        ProbeClause(probe: probe, predicates: predicates + [predicate], actions: actions)
    }

    /// Returns a new clause with the given target added.
    ///
    /// ```swift
    /// let clause = Probe("syscall:::entry") { Count() }
    /// let filtered = clause.adding(target: .execname("nginx"))
    /// ```
    public func adding(target: DTraceTarget) -> ProbeClause {
        if target.predicate.isEmpty {
            return self
        }
        return ProbeClause(probe: probe, predicates: predicates + [target.predicate], actions: actions)
    }

    func render() -> String {
        var result = probe

        if !predicates.isEmpty {
            let combined = predicates.map { "(\($0))" }.joined(separator: " && ")
            result += "\n/\(combined)/"
        }

        result += "\n{\n"
        for action in actions {
            let lines = action.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines {
                result += "    \(line)\n"
            }
        }
        result += "}"

        return result
    }
}

// MARK: - Probe Component

/// A component that can appear inside a probe clause.
public struct ProbeComponent: Sendable {
    enum Kind: Sendable {
        case predicate(String)
        case action(String)
    }

    let kind: Kind
}

// MARK: - Convenience Type Alias

/// Shorthand for creating a probe clause.
public typealias Probe = ProbeClause

// MARK: - Protocol for Clause Conversion

/// Protocol for types that can be converted to a ProbeClause.
public protocol ProbeClauseConvertible {
    func asProbeClause() -> ProbeClause
}

extension ProbeClause: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { self }
}

// MARK: - Protocol for Component Conversion

/// Protocol for types that can be converted to a ProbeComponent.
public protocol ProbeComponentConvertible {
    func asProbeComponent() -> ProbeComponent
}

extension ProbeComponent: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { self }
}

// MARK: - ProbeClauseBuilder Extension

extension ProbeClauseBuilder {
    public static func buildExpression(_ expression: ProbeComponent) -> [ProbeComponent] {
        [expression]
    }

    public static func buildExpression<T: ProbeComponentConvertible>(_ expression: T) -> [ProbeComponent] {
        [expression.asProbeComponent()]
    }
}
