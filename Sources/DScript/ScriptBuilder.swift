/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

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

// MARK: - Result Builder

/// A result builder for constructing DTrace scripts with compile-time safety.
///
/// Use `@DScriptBuilder` to create scripts declaratively:
///
/// ```swift
/// let script = DScript {
///     BEGIN {
///         Printf("Tracing started...")
///     }
///
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         When("arg0 > 0")
///         Count(by: "probefunc")
///     }
///
///     Tick(1, .seconds) {
///         Printa()
///     }
///
///     END {
///         Printf("Tracing complete")
///     }
/// }
/// ```
@resultBuilder
public struct DScriptBuilder {
    public static func buildBlock(_ components: [ProbeClause]...) -> [ProbeClause] {
        components.flatMap { $0 }
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

// MARK: - Special Clauses (BEGIN, END, ERROR, Tick, Profile)

/// Creates a BEGIN clause that fires when the script starts.
///
/// The BEGIN clause fires once when tracing begins, before any other probes.
/// Use it to initialize variables, print headers, or set up state.
///
/// ```swift
/// let script = DScript {
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
/// let script = DScript {
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
/// let script = DScript {
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
/// let script = DScript {
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
/// let script = DScript {
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

// MARK: - Protocol for Clause Conversion

/// Protocol for types that can be converted to a ProbeClause.
public protocol ProbeClauseConvertible {
    func asProbeClause() -> ProbeClause
}

extension ProbeClause: ProbeClauseConvertible {
    public func asProbeClause() -> ProbeClause { self }
}

// MARK: - DScriptBuilder Extension for Special Clauses

extension DScriptBuilder {
    public static func buildExpression(_ expression: ProbeClause) -> [ProbeClause] {
        [expression]
    }

    public static func buildExpression(_ expression: BEGIN) -> [ProbeClause] {
        [expression.asProbeClause()]
    }

    public static func buildExpression(_ expression: END) -> [ProbeClause] {
        [expression.asProbeClause()]
    }

    public static func buildExpression(_ expression: ERROR) -> [ProbeClause] {
        [expression.asProbeClause()]
    }

    public static func buildExpression(_ expression: Tick) -> [ProbeClause] {
        [expression.asProbeClause()]
    }

    public static func buildExpression(_ expression: Profile) -> [ProbeClause] {
        [expression.asProbeClause()]
    }
}

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
/// // Simple count by function name
/// Probe("syscall:::entry") {
///     Count(by: "probefunc")
/// }
///
/// // Named aggregation
/// Probe("syscall:::entry") {
///     Count(by: "probefunc", into: "syscalls")
/// }
///
/// // Multi-key aggregation
/// Probe("syscall:::entry") {
///     Count(by: ["execname", "probefunc"])
/// }
/// ```
public struct Count: Sendable {
    public let component: ProbeComponent

    /// Creates a count aggregation with a single key.
    ///
    /// - Parameters:
    ///   - key: The key expression (default: "probefunc").
    ///   - name: Optional aggregation name for referencing in Printa/Clear/Trunc.
    public init(by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = count();"))
    }

    /// Creates a count aggregation with multiple keys.
    ///
    /// - Parameters:
    ///   - keys: Array of key expressions.
    ///   - name: Optional aggregation name.
    public init(by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = count();"))
    }

    /// Creates a simple unnamed count (no keys).
    public init() {
        self.component = ProbeComponent(kind: .action("@ = count();"))
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
///
/// // With multi-key and name
/// Probe("syscall::read:return") {
///     Sum("arg0", by: ["execname", "probefunc"], into: "bytes")
/// }
/// ```
public struct Sum: Sendable {
    public let component: ProbeComponent

    /// Creates a sum aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = sum(\(value));"))
    }

    /// Creates a sum aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = sum(\(value));"))
    }
}

extension Sum: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a min aggregation.
public struct Min: Sendable {
    public let component: ProbeComponent

    /// Creates a min aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = min(\(value));"))
    }

    /// Creates a min aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = min(\(value));"))
    }
}

extension Min: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a max aggregation.
public struct Max: Sendable {
    public let component: ProbeComponent

    /// Creates a max aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = max(\(value));"))
    }

    /// Creates a max aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = max(\(value));"))
    }
}

extension Max: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds an average aggregation.
public struct Avg: Sendable {
    public let component: ProbeComponent

    /// Creates an average aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = avg(\(value));"))
    }

    /// Creates an average aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = avg(\(value));"))
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
///
/// // Named quantize for latency
/// Probe("syscall::read:return") {
///     Quantize("timestamp - self->ts", by: "execname", into: "latency")
/// }
/// ```
public struct Quantize: Sendable {
    public let component: ProbeComponent

    /// Creates a quantize aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = quantize(\(value));"))
    }

    /// Creates a quantize aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = quantize(\(value));"))
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
///
/// // Named for later reference
/// Probe("syscall::read:return") {
///     Lquantize("arg0", low: 0, high: 1000, step: 100, by: "execname", into: "sizes")
/// }
/// ```
public struct Lquantize: Sendable {
    public let component: ProbeComponent

    /// Creates a linear quantize aggregation with a single key.
    public init(_ value: String, low: Int, high: Int, step: Int, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(
            kind: .action("@\(aggName)[\(key)] = lquantize(\(value), \(low), \(high), \(step));")
        )
    }

    /// Creates a linear quantize aggregation with multiple keys.
    public init(_ value: String, low: Int, high: Int, step: Int, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(
            kind: .action("@\(aggName)[\(keyList)] = lquantize(\(value), \(low), \(high), \(step));")
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

// MARK: - Variables

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

/// Assigns a value to a variable.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Assign(.thread("ts"), to: "timestamp")
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

// MARK: - Control Actions

/// Exits the DTrace program.
///
/// ```swift
/// Tick(60, .seconds) {
///     Exit(0)  // Exit after 60 seconds
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

// MARK: - Additional Output Actions

/// Copies a string from user space.
///
/// ```swift
/// Probe("syscall::open:entry") {
///     Printf("Opening: %s", "copyinstr(arg0)")
/// }
/// ```
/// Note: Usually used inline in Printf. This provides a standalone action.
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

/// String-related actions.
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
