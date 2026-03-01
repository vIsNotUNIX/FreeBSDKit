/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

@_exported import DTraceCore

import Foundation
import Glibc

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

// MARK: - DScript

/// A type-safe DTrace script built using Swift result builders.
///
/// `DScript` provides a declarative way to construct DTrace programs
/// with compile-time type checking and IDE support.
///
/// ## Quick Start
///
/// ```swift
/// import DScript
///
/// let script = DScript {
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         Count(by: "probefunc")
///     }
/// }
///
/// print(script.source)  // See the generated D code
/// ```
///
/// ## Running Scripts
///
/// Run directly on the script instance:
///
/// ```swift
/// try script.run()              // Run until Exit()
/// try script.run(for: 10)       // Run for 10 seconds
/// let output = try script.capture()  // Capture output
/// ```
///
/// Or use static methods:
///
/// ```swift
/// try DScript.run {
///     Probe("syscall:::entry") { Count() }
///     Tick(5, .seconds) { Exit(0) }
/// }
/// ```
///
/// ## Script Structure
///
/// A DScript consists of probe clauses. Each clause has:
/// - A probe specification (e.g., "syscall:::entry")
/// - Optional predicates to filter when it fires
/// - Actions to execute when it fires
///
/// ```swift
/// let script = DScript {
///     BEGIN {
///         Printf("Starting trace...")
///     }
///
///     Probe("syscall::read:entry") {
///         Target(.execname("myapp"))    // Predicate
///         When("arg0 > 0")              // Predicate
///         Timestamp()                    // Action
///     }
///
///     Probe("syscall::read:return") {
///         When("self->ts")
///         Latency(by: "execname")
///     }
///
///     END {
///         Printa()
///     }
/// }
/// ```
public struct DScript: Sendable, CustomStringConvertible {
    public private(set) var clauses: [ProbeClause]

    public init(@DScriptBuilder _ builder: () -> [ProbeClause]) {
        self.clauses = builder()
    }

    /// Creates an empty script for programmatic construction.
    public init() {
        self.clauses = []
    }

    /// Creates a script from an array of probe clauses.
    public init(clauses: [ProbeClause]) {
        self.clauses = clauses
    }

    // MARK: - Composing Scripts

    /// Adds a probe clause to this script.
    ///
    /// ```swift
    /// var script = DScript()
    /// script.add(Probe("syscall:::entry") { Count() })
    /// ```
    public mutating func add(_ clause: ProbeClause) {
        clauses.append(clause)
    }

    /// Adds a probe clause using a result builder.
    ///
    /// ```swift
    /// var script = DScript()
    /// script.add("syscall:::entry") {
    ///     Count(by: "probefunc")
    /// }
    /// ```
    public mutating func add(_ probe: String, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        clauses.append(ProbeClause(probe, builder))
    }

    /// Adds multiple probe clauses from another script.
    ///
    /// DTrace allows multiple clauses for the same probe (including multiple
    /// BEGIN/END clauses). Each fires independently in the order they appear.
    ///
    /// ```swift
    /// var script = DScript { BEGIN { Printf("Starting...") } }
    /// script.merge(DScript.syscallCounts(for: .execname("nginx")))
    /// ```
    ///
    /// - Note: Be careful when merging scripts that use the same thread-local
    ///   variables (e.g., `self->ts`). If both scripts use the same variable
    ///   for different purposes, they will interfere with each other.
    ///   Shared aggregation names (e.g., `@bytes`) are usually intentional.
    public mutating func merge(_ other: DScript) {
        clauses.append(contentsOf: other.clauses)
    }

    /// Returns a new script with the given clause added.
    ///
    /// ```swift
    /// let base = DScript { BEGIN { Printf("Starting...") } }
    /// let extended = base.adding(Probe("syscall:::entry") { Count() })
    /// ```
    public func adding(_ clause: ProbeClause) -> DScript {
        DScript(clauses: clauses + [clause])
    }

    /// Returns a new script with another script's clauses merged.
    ///
    /// DTrace allows multiple clauses for the same probe (including multiple
    /// BEGIN/END clauses). Each fires independently in the order they appear.
    ///
    /// ```swift
    /// let base = DScript { BEGIN { Printf("Starting...") } }
    /// let combined = base.merging(DScript.syscallCounts())
    /// ```
    ///
    /// - Note: Be careful when merging scripts that use the same thread-local
    ///   variables (e.g., `self->ts`). If both scripts use the same variable
    ///   for different purposes, they will interfere with each other.
    public func merging(_ other: DScript) -> DScript {
        DScript(clauses: clauses + other.clauses)
    }

    /// Combines two scripts using the + operator.
    ///
    /// DTrace allows multiple clauses for the same probe. Each fires
    /// independently in the order they appear.
    ///
    /// ```swift
    /// let combined = DScript { BEGIN { Printf("Start") } }
    ///              + DScript.syscallCounts()
    ///              + DScript { END { Printf("Done") } }
    /// ```
    ///
    /// - Note: Be careful when combining scripts that use the same thread-local
    ///   variables (e.g., `self->ts`) for different purposes.
    public static func + (lhs: DScript, rhs: DScript) -> DScript {
        lhs.merging(rhs)
    }

    /// Appends another script's clauses using the += operator.
    public static func += (lhs: inout DScript, rhs: DScript) {
        lhs.merge(rhs)
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

    // MARK: - JSON Serialization

    /// The script structure as JSON data.
    ///
    /// This represents the script's structure, not the D source code.
    /// Useful for serialization, storage, or transmission.
    ///
    /// ```swift
    /// let script = DScript { Probe("syscall:::entry") { Count() } }
    /// let data = try script.jsonData()
    /// // ... store or transmit ...
    /// let restored = try DScript(jsonData: data)
    /// ```
    public func jsonData() throws -> Data {
        let representation: [String: Any] = [
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
        return try JSONSerialization.data(withJSONObject: representation, options: [.prettyPrinted, .sortedKeys])
    }

    /// Creates a script from JSON data.
    ///
    /// This allows round-tripping scripts through JSON for modification,
    /// storage, or transmission.
    ///
    /// ```swift
    /// // Modify a script via JSON
    /// var script = DScript { Probe("syscall:::entry") { Count() } }
    /// let data = script.jsonData!
    ///
    /// // Later, reconstruct it
    /// let restored = try DScript(jsonData: data)
    /// ```
    ///
    /// - Parameter data: JSON data representing a script.
    /// - Throws: `DScriptError.invalidJSON` if parsing fails.
    public init(jsonData data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clausesArray = json["clauses"] as? [[String: Any]] else {
            throw DScriptError.invalidJSON("Failed to parse JSON structure")
        }

        var clauses: [ProbeClause] = []
        for (index, clauseDict) in clausesArray.enumerated() {
            guard let probe = clauseDict["probe"] as? String else {
                throw DScriptError.invalidJSON("Clause \(index) missing 'probe' field")
            }
            guard let actions = clauseDict["actions"] as? [String] else {
                throw DScriptError.invalidJSON("Clause \(index) missing 'actions' field")
            }
            let predicates = clauseDict["predicates"] as? [String] ?? []

            clauses.append(ProbeClause(probe: probe, predicates: predicates, actions: actions))
        }

        self.clauses = clauses
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

    // MARK: - Execution

    /// Runs this script until it exits (via `Exit()` action).
    ///
    /// This is the simplest way to run a script. Handles session creation,
    /// enabling probes, processing output, and printing aggregations.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    ///
    /// try script.run()
    /// ```
    ///
    /// - Note: Requires root privileges.
    public func run() throws {
        var session = try DTraceSession.create()
        session.add(self)
        try session.run()
    }

    /// Runs this script for a specific duration.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    ///
    /// try script.run(for: 10)  // Run for 10 seconds
    /// ```
    ///
    /// - Parameter seconds: Duration to run before stopping.
    /// - Note: Requires root privileges.
    public func run(for seconds: TimeInterval) throws {
        var session = try DTraceSession.create()
        session.add(self)
        try session.run(for: seconds)
    }

    /// Runs this script and captures all output as a string.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Printf("%s", "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    ///
    /// let output = try script.capture()
    /// ```
    ///
    /// - Returns: All trace output as a string.
    /// - Note: Requires root privileges.
    public func capture() throws -> String {
        let buffer = DTraceOutputBuffer()
        var session = try DTraceSession.create()
        session.output(to: .buffer(buffer))
        session.add(self)
        try session.run()
        return buffer.contents
    }

    /// Runs this script for a duration and captures output as a string.
    ///
    /// ```swift
    /// let output = try script.capture(for: 10)
    /// ```
    ///
    /// - Parameter seconds: Duration to run before stopping.
    /// - Returns: All trace output as a string.
    /// - Note: Requires root privileges.
    public func capture(for seconds: TimeInterval) throws -> String {
        let buffer = DTraceOutputBuffer()
        var session = try DTraceSession.create()
        session.output(to: .buffer(buffer))
        session.add(self)
        try session.run(for: seconds)
        return buffer.contents
    }

    // MARK: - Static Execution Methods

    /// Builds and runs a script until it exits.
    ///
    /// ```swift
    /// try DScript.run {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    /// ```
    ///
    /// - Note: Requires root privileges.
    public static func run(@DScriptBuilder _ builder: () -> [ProbeClause]) throws {
        try DScript(builder).run()
    }

    /// Builds and runs a script for a specific duration.
    ///
    /// ```swift
    /// try DScript.run(for: 10) {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    ///
    /// - Note: Requires root privileges.
    public static func run(
        for seconds: TimeInterval,
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws {
        try DScript(builder).run(for: seconds)
    }

    /// Builds and runs a script, capturing output as a string.
    ///
    /// ```swift
    /// let output = try DScript.capture {
    ///     Probe("syscall:::entry") {
    ///         Printf("%s", "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    /// ```
    ///
    /// - Returns: All trace output as a string.
    /// - Note: Requires root privileges.
    public static func capture(
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try DScript(builder).capture()
    }

    /// Builds and runs a script for a duration, capturing output.
    ///
    /// ```swift
    /// let output = try DScript.capture(for: 10) {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: All trace output as a string.
    /// - Note: Requires root privileges.
    public static func capture(
        for seconds: TimeInterval,
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try DScript(builder).capture(for: seconds)
    }
}

// MARK: - Errors

/// Errors that can occur when building or compiling a DTrace script.
public enum DScriptError: Error, CustomStringConvertible {
    /// The script contains no probe clauses.
    case emptyScript

    /// A probe clause has no actions.
    case emptyClause(probe: String, index: Int)

    /// The D script failed to compile.
    case compilationFailed(source: String, error: String)

    /// Invalid JSON format.
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .emptyScript:
            return "Script contains no probe clauses"
        case .emptyClause(let probe, let index):
            return "Probe clause \(index) '\(probe)' has no actions"
        case .compilationFailed(_, let error):
            return "D script compilation failed: \(error)"
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        }
    }
}
