/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

// MARK: - Result Builder

/// A result builder for constructing DTrace scripts with compile-time safety.
///
/// Use `@DScriptBuilder` to create scripts declaratively:
///
/// ```swift
/// let script = DScript {
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         When("arg0 > 0")
///         Count(by: "probefunc")
///     }
///     Probe("syscall:::return") {
///         Target(.pid(1234))
///         Printf("%s: %d", "execname", "arg0")
///     }
/// }
/// ```
@resultBuilder
public struct DScriptBuilder {
    public static func buildBlock(_ components: ProbeClause...) -> [ProbeClause] {
        components
    }

    public static func buildArray(_ components: [[ProbeClause]]) -> [ProbeClause] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [ProbeClause]?) -> [ProbeClause] {
        component ?? []
    }

    public static func buildEither(first component: [ProbeClause]) -> [ProbeClause] {
        component
    }

    public static func buildEither(second component: [ProbeClause]) -> [ProbeClause] {
        component
    }
}

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

// MARK: - DScript (Main Entry Point)

/// Creates a DTrace script using the result builder syntax.
///
/// ## Example
///
/// ```swift
/// let script = DScript {
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         Count(by: "probefunc")
///     }
/// }
/// print(script.source)
/// ```
public struct DScript: Sendable, CustomStringConvertible {
    public let clauses: [ProbeClause]

    public init(@DScriptBuilder _ builder: () -> [ProbeClause]) {
        self.clauses = builder()
    }

    /// The generated D source code.
    public var source: String {
        clauses.map { $0.render() }.joined(separator: "\n\n")
    }

    public var description: String {
        source
    }

    // MARK: - Data Conversion

    /// The generated D source code as UTF-8 data.
    public var data: Data {
        Data(source.utf8)
    }

    /// The generated D source code as UTF-8 data with a null terminator.
    public var nullTerminatedData: Data {
        var data = Data(source.utf8)
        data.append(0)
        return data
    }

    /// Writes the script to a file.
    ///
    /// - Parameter path: The file path to write to.
    /// - Throws: Any file system errors.
    public func write(to path: String) throws {
        try source.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Writes the script to a URL.
    ///
    /// - Parameter url: The URL to write to.
    /// - Throws: Any file system errors.
    public func write(to url: URL) throws {
        try source.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - JSON Representation

    /// A JSON-serializable representation of the script structure.
    public var jsonRepresentation: [String: Any] {
        [
            "version": 1,
            "clauses": clauses.map { clause in
                var dict: [String: Any] = [
                    "probe": clause.probe,
                    "actions": clause.actions
                ]
                if !clause.predicates.isEmpty {
                    dict["predicates"] = clause.predicates
                }
                return dict
            }
        ]
    }

    /// The script structure as JSON data.
    ///
    /// This represents the script's AST, not the D source code.
    /// Useful for serialization, storage, or sending to other tools.
    public var jsonData: Data? {
        try? JSONSerialization.data(withJSONObject: jsonRepresentation, options: [.prettyPrinted, .sortedKeys])
    }

    /// The script structure as a JSON string.
    public var jsonString: String? {
        guard let data = jsonData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Validation

    /// Validates the script structure.
    ///
    /// - Throws: `DScriptError` if the script is invalid.
    public func validate() throws {
        if clauses.isEmpty {
            throw DScriptError.emptyScript
        }
        for (index, clause) in clauses.enumerated() {
            if clause.actions.isEmpty {
                throw DScriptError.emptyClause(probe: clause.probe, index: index)
            }
        }
    }

    /// Compiles the script using DTrace to validate D syntax.
    ///
    /// This actually invokes the DTrace compiler to check for syntax errors,
    /// undefined variables, invalid probe specifications, etc.
    ///
    /// - Returns: `true` if compilation succeeded.
    /// - Throws: `DScriptError.compilationFailed` with details if compilation fails,
    ///           or other errors if DTrace cannot be initialized.
    ///
    /// - Note: Requires appropriate privileges (typically root) to open DTrace.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Count()
    ///     }
    /// }
    ///
    /// do {
    ///     try script.compile()
    ///     print("Script is valid!")
    /// } catch let error as DScriptError {
    ///     print("Compilation failed: \(error)")
    /// }
    /// ```
    @discardableResult
    public func compile() throws -> Bool {
        // First do structural validation
        try validate()

        // Try to compile with DTrace
        let handle = try DTraceHandle.open()
        do {
            let program = try handle.compile(source)
            // Program compiled successfully - we don't need to exec it
            _ = program
            return true
        } catch let error as DTraceCoreError {
            let message: String
            switch error {
            case .compileFailed(let msg):
                message = msg
            case .openFailed(_, let msg):
                message = "Failed to open DTrace: \(msg)"
            default:
                message = String(describing: error)
            }
            throw DScriptError.compilationFailed(
                source: source,
                error: message
            )
        }
    }

    /// Checks if the script compiles without throwing.
    ///
    /// - Returns: `true` if compilation succeeds, `false` otherwise.
    ///
    /// - Note: Requires appropriate privileges (typically root) to open DTrace.
    public var isValid: Bool {
        (try? compile()) ?? false
    }
}

/// Errors that can occur when building a DTrace script.
public enum DScriptError: Error, CustomStringConvertible {
    case emptyScript
    case emptyClause(probe: String, index: Int)
    case compilationFailed(source: String, error: String)

    public var description: String {
        switch self {
        case .emptyScript:
            return "Script contains no probe clauses"
        case .emptyClause(let probe, let index):
            return "Probe clause \(index) '\(probe)' has no actions"
        case .compilationFailed(_, let error):
            return "D script compilation failed: \(error)"
        }
    }
}

// MARK: - Probe Clause

/// A single probe clause in a DTrace script.
///
/// Each clause consists of a probe specification, optional predicates,
/// and one or more actions.
public struct ProbeClause: Sendable {
    public let probe: String
    public let predicates: [String]
    public let actions: [String]

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
    public init(probe: String, predicates: [String] = [], actions: [String]) {
        self.probe = probe
        self.predicates = predicates
        self.actions = actions
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

// MARK: - Probe Component Protocol

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

// MARK: - Predicate Components

/// Sets the target filter for this probe clause.
///
/// ```swift
/// Probe("syscall:::entry") {
///     Target(.execname("nginx"))
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

/// Adds a custom predicate condition.
///
/// ```swift
/// Probe("syscall:::entry") {
///     When("arg0 > 0")
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

// MARK: - Action Components

/// Adds a count aggregation.
///
/// ```swift
/// Probe("syscall:::entry") {
///     Count(by: "probefunc")
/// }
/// ```
public struct Count: Sendable {
    public let component: ProbeComponent

    public init(by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = count();"))
    }
}

extension Count: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a sum aggregation.
///
/// ```swift
/// Probe("syscall::read:return") {
///     When("arg0 > 0")
///     Sum("arg0", by: "execname")
/// }
/// ```
public struct Sum: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = sum(\(value));"))
    }
}

extension Sum: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a min aggregation.
public struct Min: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = min(\(value));"))
    }
}

extension Min: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a max aggregation.
public struct Max: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = max(\(value));"))
    }
}

extension Max: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds an average aggregation.
public struct Avg: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = avg(\(value));"))
    }
}

extension Avg: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a quantize (power-of-2 histogram) aggregation.
///
/// ```swift
/// Probe("syscall::read:return") {
///     Quantize("arg0", by: "execname")
/// }
/// ```
public struct Quantize: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, by key: String = "probefunc") {
        self.component = ProbeComponent(kind: .action("@[\(key)] = quantize(\(value));"))
    }
}

extension Quantize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a linear quantize aggregation.
///
/// ```swift
/// Probe("syscall::read:return") {
///     Lquantize("arg0", low: 0, high: 1000, step: 100, by: "execname")
/// }
/// ```
public struct Lquantize: Sendable {
    public let component: ProbeComponent

    public init(_ value: String, low: Int, high: Int, step: Int, by key: String = "probefunc") {
        self.component = ProbeComponent(
            kind: .action("@[\(key)] = lquantize(\(value), \(low), \(high), \(step));")
        )
    }
}

extension Lquantize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a printf action.
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
/// ```swift
/// Probe("fbt::malloc:entry") {
///     Stack()           // Kernel stack
///     Stack(userland: true)  // User stack
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
///
/// ```swift
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

// MARK: - Predefined Scripts

extension DScript {
    /// Creates a syscall counting script.
    ///
    /// ```swift
    /// let script = DScript.syscallCounts(for: .execname("nginx"))
    /// ```
    public static func syscallCounts(for target: DTraceTarget = .all) -> DScript {
        if target.predicate.isEmpty {
            return DScript {
                Probe("syscall:freebsd::entry") {
                    Count(by: "probefunc")
                }
            }
        } else {
            return DScript {
                Probe("syscall:freebsd::entry") {
                    Target(target)
                    Count(by: "probefunc")
                }
            }
        }
    }

    /// Creates a file open tracing script.
    public static func fileOpens(for target: DTraceTarget = .all) -> DScript {
        if target.predicate.isEmpty {
            return DScript {
                Probe("syscall:freebsd:open*:entry") {
                    Printf("%s: %s", "execname", "copyinstr(arg0)")
                }
            }
        } else {
            return DScript {
                Probe("syscall:freebsd:open*:entry") {
                    Target(target)
                    Printf("%s: %s", "execname", "copyinstr(arg0)")
                }
            }
        }
    }

    /// Creates a CPU profiling script.
    public static func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) -> DScript {
        if target.predicate.isEmpty {
            return DScript {
                Probe("profile-\(hz)") {
                    Count(by: "execname")
                }
            }
        } else {
            return DScript {
                Probe("profile-\(hz)") {
                    Target(target)
                    Count(by: "execname")
                }
            }
        }
    }

    /// Creates a process exec tracing script.
    public static func processExec() -> DScript {
        DScript {
            Probe("proc:::exec-success") {
                Printf("%s[%d] exec'd %s", "execname", "pid", "curpsinfo->pr_psargs")
            }
        }
    }

    /// Creates an I/O bytes tracking script.
    public static func ioBytes(for target: DTraceTarget = .all) -> DScript {
        if target.predicate.isEmpty {
            return DScript {
                Probe("syscall:freebsd:read:return") {
                    When("arg0 > 0")
                    Sum("arg0", by: "execname")
                }
                Probe("syscall:freebsd:write:return") {
                    When("arg0 > 0")
                    Sum("arg0", by: "execname")
                }
            }
        } else {
            return DScript {
                Probe("syscall:freebsd:read:return") {
                    Target(target)
                    When("arg0 > 0")
                    Sum("arg0", by: "execname")
                }
                Probe("syscall:freebsd:write:return") {
                    Target(target)
                    When("arg0 > 0")
                    Sum("arg0", by: "execname")
                }
            }
        }
    }

    /// Creates a syscall latency measurement script.
    public static func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) -> DScript {
        if target.predicate.isEmpty {
            return DScript {
                Probe("syscall:freebsd:\(syscall):entry") {
                    Timestamp()
                }
                Probe("syscall:freebsd:\(syscall):return") {
                    When("self->ts")
                    Latency(by: "execname")
                }
            }
        } else {
            return DScript {
                Probe("syscall:freebsd:\(syscall):entry") {
                    Target(target)
                    Timestamp()
                }
                Probe("syscall:freebsd:\(syscall):return") {
                    Target(target)
                    When("self->ts")
                    Latency(by: "execname")
                }
            }
        }
    }
}
