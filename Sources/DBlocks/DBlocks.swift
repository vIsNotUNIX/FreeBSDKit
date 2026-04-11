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
/// Use `@DBlocksBuilder` to create scripts declaratively:
///
/// ```swift
/// let script = DBlocks {
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
public struct DBlocksBuilder {
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

// MARK: - DBlocks

/// A type-safe DTrace script built using Swift result builders.
///
/// `DBlocks` provides a declarative way to construct DTrace programs
/// with compile-time type checking and IDE support.
///
/// ## Quick Start
///
/// ```swift
/// import DBlocks
///
/// let script = DBlocks {
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
/// try DBlocks.run {
///     Probe("syscall:::entry") { Count() }
///     Tick(5, .seconds) { Exit(0) }
/// }
/// ```
///
/// ## Script Structure
///
/// A DBlocks consists of probe clauses. Each clause has:
/// - A probe specification (e.g., "syscall:::entry")
/// - Optional predicates to filter when it fires
/// - Actions to execute when it fires
///
/// ```swift
/// let script = DBlocks {
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
public struct DBlocks: Sendable, Codable, CustomStringConvertible {
    /// Version of the serialization format for forward compatibility.
    private static let serializationVersion = 1

    public private(set) var clauses: [ProbeClause]

    private enum CodingKeys: String, CodingKey {
        case version
        case clauses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Version is optional for forward compatibility - we can read older formats
        _ = try container.decodeIfPresent(Int.self, forKey: .version)
        self.clauses = try container.decode([ProbeClause].self, forKey: .clauses)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.serializationVersion, forKey: .version)
        try container.encode(clauses, forKey: .clauses)
    }

    public init(@DBlocksBuilder _ builder: () -> [ProbeClause]) {
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
    /// var script = DBlocks()
    /// script.add(Probe("syscall:::entry") { Count() })
    /// ```
    public mutating func add(_ clause: ProbeClause) {
        clauses.append(clause)
    }

    /// Adds a probe clause using a result builder.
    ///
    /// ```swift
    /// var script = DBlocks()
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
    /// var script = DBlocks { BEGIN { Printf("Starting...") } }
    /// script.merge(DBlocks.syscallCounts(for: .execname("nginx")))
    /// ```
    ///
    /// - Note: Be careful when merging scripts that use the same thread-local
    ///   variables (e.g., `self->ts`). If both scripts use the same variable
    ///   for different purposes, they will interfere with each other.
    ///   Shared aggregation names (e.g., `@bytes`) are usually intentional.
    public mutating func merge(_ other: DBlocks) {
        clauses.append(contentsOf: other.clauses)
    }

    /// Returns a new script with the given clause added.
    ///
    /// ```swift
    /// let base = DBlocks { BEGIN { Printf("Starting...") } }
    /// let extended = base.adding(Probe("syscall:::entry") { Count() })
    /// ```
    public func adding(_ clause: ProbeClause) -> DBlocks {
        DBlocks(clauses: clauses + [clause])
    }

    /// Returns a new script with another script's clauses merged.
    ///
    /// DTrace allows multiple clauses for the same probe (including multiple
    /// BEGIN/END clauses). Each fires independently in the order they appear.
    ///
    /// ```swift
    /// let base = DBlocks { BEGIN { Printf("Starting...") } }
    /// let combined = base.merging(DBlocks.syscallCounts())
    /// ```
    ///
    /// - Note: Be careful when merging scripts that use the same thread-local
    ///   variables (e.g., `self->ts`). If both scripts use the same variable
    ///   for different purposes, they will interfere with each other.
    public func merging(_ other: DBlocks) -> DBlocks {
        DBlocks(clauses: clauses + other.clauses)
    }

    /// Combines two scripts using the + operator.
    ///
    /// DTrace allows multiple clauses for the same probe. Each fires
    /// independently in the order they appear.
    ///
    /// ```swift
    /// let combined = DBlocks { BEGIN { Printf("Start") } }
    ///              + DBlocks.syscallCounts()
    ///              + DBlocks { END { Printf("Done") } }
    /// ```
    ///
    /// - Note: Be careful when combining scripts that use the same thread-local
    ///   variables (e.g., `self->ts`) for different purposes.
    public static func + (lhs: DBlocks, rhs: DBlocks) -> DBlocks {
        lhs.merging(rhs)
    }

    /// Appends another script's clauses using the += operator.
    public static func += (lhs: inout DBlocks, rhs: DBlocks) {
        lhs.merge(rhs)
    }

    // MARK: - Merge Conflict Detection

    /// Returns the set of thread-local variable names that both this
    /// script and `other` assign to.
    ///
    /// Two scripts that both write to the same `self->name` for
    /// different purposes will silently corrupt each other when merged.
    /// This method scans both sides for `self->NAME = …` assignments
    /// and reports the names that appear in both. The result is sorted
    /// for stable diagnostics.
    ///
    /// Aggregations (e.g. `@bytes[…] = sum(…);`) are *not* reported —
    /// shared aggregation names are usually intentional and DTrace
    /// itself merges them sensibly.
    ///
    /// ```swift
    /// let conflicts = a.threadLocalConflicts(with: b)
    /// if !conflicts.isEmpty {
    ///     print("conflicting thread-locals: \(conflicts)")
    /// }
    /// ```
    public func threadLocalConflicts(with other: DBlocks) -> [String] {
        let lhs = Self.threadLocalAssignments(in: clauses)
        let rhs = Self.threadLocalAssignments(in: other.clauses)
        return Array(lhs.intersection(rhs)).sorted()
    }

    /// Like `merge(_:)`, but throws if the two scripts assign to the
    /// same thread-local variable.
    ///
    /// Use this when you're combining unrelated scripts and want a
    /// loud failure rather than a silent corruption.
    ///
    /// - Throws: `DBlocksError.threadLocalConflict` listing every
    ///   name that appears in both sides.
    public mutating func mergeChecked(_ other: DBlocks) throws {
        let conflicts = threadLocalConflicts(with: other)
        if !conflicts.isEmpty {
            throw DBlocksError.threadLocalConflict(names: conflicts)
        }
        merge(other)
    }

    /// Like `merging(_:)`, but throws if the two scripts assign to the
    /// same thread-local variable.
    ///
    /// - Throws: `DBlocksError.threadLocalConflict` if any thread-local
    ///   is written by both sides.
    public func mergingChecked(_ other: DBlocks) throws -> DBlocks {
        let conflicts = threadLocalConflicts(with: other)
        if !conflicts.isEmpty {
            throw DBlocksError.threadLocalConflict(names: conflicts)
        }
        return merging(other)
    }

    /// Scans an action string for `self->NAME = …` assignments and
    /// returns the bare NAMEs.
    private static func threadLocalAssignments(in clauses: [ProbeClause]) -> Set<String> {
        var names: Set<String> = []
        let prefix = "self->"
        for clause in clauses {
            for action in clause.actions {
                var index = action.startIndex
                while let match = action.range(of: prefix, range: index..<action.endIndex) {
                    var nameEnd = match.upperBound
                    while nameEnd < action.endIndex {
                        let ch = action[nameEnd]
                        if ch.isLetter || ch.isNumber || ch == "_" {
                            nameEnd = action.index(after: nameEnd)
                        } else {
                            break
                        }
                    }
                    // Skip whitespace and check for `=` (and not `==`).
                    var afterName = nameEnd
                    while afterName < action.endIndex, action[afterName].isWhitespace {
                        afterName = action.index(after: afterName)
                    }
                    if afterName < action.endIndex, action[afterName] == "=" {
                        let next = action.index(after: afterName)
                        if next == action.endIndex || action[next] != "=" {
                            let name = String(action[match.upperBound..<nameEnd])
                            if !name.isEmpty {
                                names.insert(name)
                            }
                        }
                    }
                    index = nameEnd
                }
            }
        }
        return names
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
    /// let script = DBlocks { Probe("syscall:::entry") { Count() } }
    /// let data = try script.jsonData()
    /// // ... store or transmit ...
    /// let restored = try DBlocks(jsonData: data)
    /// ```
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Creates a script from JSON data.
    ///
    /// This allows round-tripping scripts through JSON for modification,
    /// storage, or transmission.
    ///
    /// ```swift
    /// // Modify a script via JSON
    /// var script = DBlocks { Probe("syscall:::entry") { Count() } }
    /// let data = try script.jsonData()
    ///
    /// // Later, reconstruct it
    /// let restored = try DBlocks(jsonData: data)
    /// ```
    ///
    /// - Parameter data: JSON data representing a script.
    /// - Throws: `DecodingError` if parsing fails.
    public init(jsonData data: Data) throws {
        self = try JSONDecoder().decode(DBlocks.self, from: data)
    }


    // MARK: - Validation

    /// Validates the script structure.
    ///
    /// - Throws: `DBlocksError` if the script is invalid.
    public func validate() throws {
        if clauses.isEmpty {
            throw DBlocksError.emptyScript
        }
        for (index, clause) in clauses.enumerated() {
            if clause.actions.isEmpty {
                throw DBlocksError.emptyClause(probe: clause.probe, index: index)
            }
        }
    }

    // MARK: - Linting

    /// A non-fatal advisory about a potential problem in the script.
    public struct LintWarning: Sendable, Equatable, CustomStringConvertible {
        /// What the warning is about.
        public let kind: Kind

        /// Index of the offending clause in `DBlocks.clauses`, or `nil`
        /// for whole-script warnings.
        public let clauseIndex: Int?

        public enum Kind: Sendable, Equatable {
            /// A `Printa`/`Clear`/`Trunc`/`Normalize` action references
            /// an aggregation `@name` that no clause defines.
            case undefinedAggregation(String)

            /// `Exit()` is called inside a `profile-…` probe. Profile
            /// probes fire on every CPU simultaneously, so the exit
            /// race is observable and the script may exit slightly
            /// before the user expects.
            case exitInProfileProbe(probe: String)
        }

        public var description: String {
            switch kind {
            case .undefinedAggregation(let name):
                let idx = clauseIndex.map { " (clause \($0))" } ?? ""
                return "references undefined aggregation @\(name)\(idx)"
            case .exitInProfileProbe(let probe):
                let idx = clauseIndex.map { " (clause \($0))" } ?? ""
                return "Exit() inside profile probe '\(probe)' fires on every CPU\(idx)"
            }
        }
    }

    /// Inspects the script for common, non-fatal pitfalls.
    ///
    /// Returns advisory warnings rather than throwing — none of these
    /// stop a script from compiling, but each is the kind of mistake
    /// that produces silent or surprising behavior at run time.
    /// Use alongside `validate()` (which catches structural errors)
    /// and `compile()` (which invokes the actual D parser).
    ///
    /// Currently detects:
    /// - References to a named aggregation that no clause defines.
    /// - `Exit()` actions inside `profile-…` probes (which fire on
    ///   every CPU and so the exit race is observable).
    ///
    /// ```swift
    /// for warning in script.lint() {
    ///     print("warning:", warning)
    /// }
    /// ```
    public func lint() -> [LintWarning] {
        var warnings: [LintWarning] = []

        // Build the set of aggregation names defined anywhere in the
        // script. Anonymous aggregations (`@`) are excluded — they
        // can be referenced as `@` and don't have a name to look up.
        var defined: Set<String> = []
        for clause in clauses {
            for action in clause.actions {
                Self.collectAggregationDefinitions(in: action, into: &defined)
            }
        }

        for (index, clause) in clauses.enumerated() {
            // Pitfall: Exit() inside a profile probe.
            if clause.probe.hasPrefix("profile-") {
                for action in clause.actions where action.contains("exit(") {
                    warnings.append(
                        LintWarning(
                            kind: .exitInProfileProbe(probe: clause.probe),
                            clauseIndex: index
                        )
                    )
                    break
                }
            }

            // Pitfall: referencing an aggregation that no clause defines.
            for action in clause.actions {
                let referenced = Self.aggregationReferences(in: action)
                for name in referenced where !defined.contains(name) {
                    warnings.append(
                        LintWarning(
                            kind: .undefinedAggregation(name),
                            clauseIndex: index
                        )
                    )
                }
            }
        }

        return warnings
    }

    /// Scans an action for aggregation *definitions* of the form
    /// `@NAME[…] = aggfn(…);` and adds the bare NAME to `into`.
    /// `@[…] = …;` (anonymous) is intentionally skipped.
    private static func collectAggregationDefinitions(in action: String, into set: inout Set<String>) {
        var index = action.startIndex
        while let at = action[index...].firstIndex(of: "@") {
            let nameStart = action.index(after: at)
            var nameEnd = nameStart
            while nameEnd < action.endIndex {
                let ch = action[nameEnd]
                if ch.isLetter || ch.isNumber || ch == "_" {
                    nameEnd = action.index(after: nameEnd)
                } else {
                    break
                }
            }
            let name = String(action[nameStart..<nameEnd])
            // To count as a definition, the next non-whitespace
            // character past the (optional) `[…]` must be `=` (and not
            // `==`).
            var cursor = nameEnd
            if cursor < action.endIndex, action[cursor] == "[" {
                if let close = action[cursor...].firstIndex(of: "]") {
                    cursor = action.index(after: close)
                }
            }
            while cursor < action.endIndex, action[cursor].isWhitespace {
                cursor = action.index(after: cursor)
            }
            if cursor < action.endIndex, action[cursor] == "=" {
                let next = action.index(after: cursor)
                if next == action.endIndex || action[next] != "=" {
                    if !name.isEmpty { set.insert(name) }
                }
            }
            index = nameEnd
        }
    }

    /// Scans an action for aggregation *references* inside `printa`,
    /// `clear`, `trunc`, `normalize`, or `denormalize` calls and
    /// returns the bare names. Anonymous (`@`) is skipped.
    private static func aggregationReferences(in action: String) -> [String] {
        let funcs = ["printa(", "clear(", "trunc(", "normalize(", "denormalize("]
        var names: [String] = []
        for fn in funcs {
            var search = action.startIndex
            while let call = action.range(of: fn, range: search..<action.endIndex) {
                // Find the matching close paren so we don't drift into
                // the next call.
                guard let close = action[call.upperBound...].firstIndex(of: ")") else { break }
                let body = action[call.upperBound..<close]
                // Inside the call, every `@NAME` is a reference.
                var idx = body.startIndex
                while let at = body[idx...].firstIndex(of: "@") {
                    let nameStart = body.index(after: at)
                    var nameEnd = nameStart
                    while nameEnd < body.endIndex {
                        let ch = body[nameEnd]
                        if ch.isLetter || ch.isNumber || ch == "_" {
                            nameEnd = body.index(after: nameEnd)
                        } else {
                            break
                        }
                    }
                    let name = String(body[nameStart..<nameEnd])
                    if !name.isEmpty {
                        names.append(name)
                    }
                    idx = nameEnd
                }
                search = action.index(after: close)
            }
        }
        return names
    }

    /// Compiles the script using DTrace to validate D syntax.
    ///
    /// This actually invokes the DTrace compiler to check for syntax errors,
    /// undefined variables, invalid probe specifications, etc.
    ///
    /// - Returns: `true` if compilation succeeded.
    /// - Throws: `DBlocksError.compilationFailed` with details if compilation fails,
    ///           or other errors if DTrace cannot be initialized.
    ///
    /// - Note: Requires appropriate privileges (typically root) to open DTrace.
    ///
    /// ```swift
    /// let script = DBlocks {
    ///     Probe("syscall:::entry") {
    ///         Count()
    ///     }
    /// }
    ///
    /// do {
    ///     try script.compile()
    ///     print("Script is valid!")
    /// } catch let error as DBlocksError {
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
            throw DBlocksError.compilationFailed(
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
    /// let script = DBlocks {
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
    /// let script = DBlocks {
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
    /// let script = DBlocks {
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
    /// try DBlocks.run {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    /// ```
    ///
    /// - Note: Requires root privileges.
    public static func run(@DBlocksBuilder _ builder: () -> [ProbeClause]) throws {
        try DBlocks(builder).run()
    }

    /// Builds and runs a script for a specific duration.
    ///
    /// ```swift
    /// try DBlocks.run(for: 10) {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    ///
    /// - Note: Requires root privileges.
    public static func run(
        for seconds: TimeInterval,
        @DBlocksBuilder _ builder: () -> [ProbeClause]
    ) throws {
        try DBlocks(builder).run(for: seconds)
    }

    /// Builds and runs a script, capturing output as a string.
    ///
    /// ```swift
    /// let output = try DBlocks.capture {
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
        @DBlocksBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try DBlocks(builder).capture()
    }

    /// Builds and runs a script for a duration, capturing output.
    ///
    /// ```swift
    /// let output = try DBlocks.capture(for: 10) {
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
        @DBlocksBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try DBlocks(builder).capture(for: seconds)
    }
}

// MARK: - Errors

/// Errors that can occur when building or compiling a DTrace script.
public enum DBlocksError: Error, CustomStringConvertible {
    /// The script contains no probe clauses.
    case emptyScript

    /// A probe clause has no actions.
    case emptyClause(probe: String, index: Int)

    /// The D script failed to compile.
    case compilationFailed(source: String, error: String)

    /// Invalid JSON format.
    case invalidJSON(String)

    /// Two scripts being merged both assign to the same thread-local
    /// variable(s) — at run time they would silently corrupt each
    /// other's state.
    case threadLocalConflict(names: [String])

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
        case .threadLocalConflict(let names):
            let list = names.map { "self->\($0)" }.joined(separator: ", ")
            return "Conflicting thread-local assignments between merged scripts: \(list)"
        }
    }
}
