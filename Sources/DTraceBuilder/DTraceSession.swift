/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import Glibc

/// A high-level, fluent interface for DTrace sessions.
///
/// `DTraceSession` wraps `DTraceHandle` and provides a guided experience
/// for building and running D programs.
///
/// ## Example
///
/// ```swift
/// var session = try DTraceSession()
/// session.trace("syscall:::entry")
/// session.targeting(.execname("nginx"))
/// session.counting(by: .function)
/// try session.start()
///
/// while session.work() == .okay {
///     session.sleep()
/// }
///
/// try session.printAggregations()
/// ```
public struct DTraceSession: ~Copyable {
    private var handle: DTraceHandle
    private var scripts: [DTraceScript] = []
    private var currentScript: DTraceScript?
    private var isStarted: Bool = false
    private var outputDestination: DTraceOutput = .stdout

    // MARK: - Initialization

    /// Creates a new DTrace session.
    ///
    /// - Parameter flags: Flags controlling how the session is opened.
    /// - Throws: `DTraceCoreError.openFailed` if the session cannot be created.
    public init(flags: DTraceOpenFlags = []) throws {
        self.handle = try DTraceHandle.open(flags: flags)
    }

    /// Creates a new DTrace session with configurable buffer sizes.
    ///
    /// This is the recommended way to create a session. The default buffer sizes
    /// of 4MB are appropriate for most tracing scenarios (libdtrace defaults are too small).
    ///
    /// - Parameters:
    ///   - flags: Flags controlling how the session is opened.
    ///   - traceBufferSize: Size of the trace data buffer (default: "4m").
    ///   - aggBufferSize: Size of the aggregation buffer (default: "4m").
    /// - Throws: `DTraceCoreError.openFailed` if the session cannot be created.
    public static func create(
        flags: DTraceOpenFlags = [],
        traceBufferSize: String = "4m",
        aggBufferSize: String = "4m"
    ) throws -> DTraceSession {
        var session = try DTraceSession(flags: flags)
        try session.handle.setOption("bufsize", value: traceBufferSize)
        try session.handle.setOption("aggsize", value: aggBufferSize)
        return session
    }

    // MARK: - Configuration

    /// Sets the output destination for this session.
    public mutating func output(to destination: DTraceOutput) {
        outputDestination = destination
    }

    /// Sets a DTrace option.
    public mutating func option(_ name: String, value: String? = nil) throws {
        try handle.setOption(name, value: value)
    }

    /// Enables quiet mode (suppresses default output).
    public mutating func quiet() throws {
        try option("quiet")
    }

    /// Sets the trace buffer size.
    public mutating func traceBufferSize(_ size: String) throws {
        try option("bufsize", value: size)
    }

    /// Sets the aggregation buffer size.
    public mutating func aggBufferSize(_ size: String) throws {
        try option("aggsize", value: size)
    }

    // MARK: - Script Building

    /// Starts tracing the specified probe.
    public mutating func trace(_ probeSpec: String) {
        finalizeCurrentScript()
        currentScript = DTraceScript(probeSpec)
    }

    /// Sets the target filter for the current probe.
    public mutating func targeting(_ target: DTraceTarget) {
        if let script = currentScript {
            currentScript = script.targeting(target)
        }
    }

    /// Adds a custom predicate condition.
    public mutating func when(_ predicate: String) {
        if let script = currentScript {
            currentScript = script.when(predicate)
        }
    }

    /// Sets a raw action for the current probe.
    public mutating func action(_ code: String) {
        if let script = currentScript {
            currentScript = script.action(code)
        }
    }

    // MARK: - Aggregation Keys

    /// What to aggregate by.
    public enum AggregationKey: Sendable {
        case function
        case execname
        case pid
        case uid
        case cpu
        case custom(String)

        public var expression: String {
            switch self {
            case .function: return "probefunc"
            case .execname: return "execname"
            case .pid: return "pid"
            case .uid: return "uid"
            case .cpu: return "cpu"
            case .custom(let expr): return expr
            }
        }
    }

    /// Adds a count aggregation.
    public mutating func counting(by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.count(by: key.expression)
        }
    }

    /// Adds a sum aggregation.
    public mutating func summing(_ value: String, by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.sum(value, by: key.expression)
        }
    }

    /// Adds a histogram (quantize) aggregation.
    public mutating func histogram(_ value: String, by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.quantize(value, by: key.expression)
        }
    }

    /// Adds a min aggregation.
    public mutating func minimum(_ value: String, by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.min(value, by: key.expression)
        }
    }

    /// Adds a max aggregation.
    public mutating func maximum(_ value: String, by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.max(value, by: key.expression)
        }
    }

    /// Adds an average aggregation.
    public mutating func averaging(_ value: String, by key: AggregationKey = .function) {
        if let script = currentScript {
            currentScript = script.avg(value, by: key.expression)
        }
    }

    /// Adds a printf action.
    public mutating func printf(_ format: String, _ args: String...) {
        if let script = currentScript {
            let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
            currentScript = script.action("printf(\"\(format)\\n\"\(argList));")
        }
    }

    /// Adds a stack trace.
    public mutating func stackTrace(userland: Bool = false) {
        if let script = currentScript {
            currentScript = script.stack(userland: userland)
        }
    }

    // MARK: - Predefined Traces

    /// Traces syscall counts for a target.
    public mutating func syscallCounts(for target: DTraceTarget = .all) {
        finalizeCurrentScript()
        scripts.append(.syscallCounts(for: target))
    }

    /// Traces file opens for a target.
    public mutating func fileOpens(for target: DTraceTarget = .all) {
        finalizeCurrentScript()
        scripts.append(.fileOpens(for: target))
    }

    /// Profiles CPU usage.
    public mutating func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) {
        finalizeCurrentScript()
        scripts.append(.cpuProfile(hz: hz, for: target))
    }

    /// Traces I/O bytes.
    public mutating func ioBytes(for target: DTraceTarget = .all) {
        finalizeCurrentScript()
        scripts.append(.ioBytes(for: target))
    }

    /// Traces syscall latency.
    public mutating func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) {
        finalizeCurrentScript()
        scripts.append(.syscallLatency(syscall, for: target))
    }

    // MARK: - Execution

    /// Compiles and starts the tracing session.
    ///
    /// - Throws: Any compilation or execution errors.
    public mutating func start() throws {
        finalizeCurrentScript()

        for script in scripts {
            let source = script.build()
            let program = try handle.compile(source)
            try handle.exec(program)
        }

        try handle.go()
        isStarted = true
    }

    /// Processes available trace data.
    ///
    /// - Returns: The work status indicating whether to continue processing.
    public func work() -> DTraceWorkStatus {
        outputDestination.withFilePointer { fp in
            handle.work(to: fp)
        }
    }

    /// Processes available trace data to a specific output.
    ///
    /// - Parameter output: Where to write the output.
    /// - Returns: The work status indicating whether to continue processing.
    public func work(to output: DTraceOutput) -> DTraceWorkStatus {
        output.withFilePointer { fp in
            handle.work(to: fp)
        }
    }

    /// Waits for data to be available.
    public func sleep() {
        handle.sleep()
    }

    /// Stops tracing.
    public func stop() throws {
        try handle.stop()
    }

    /// Gets the current session status.
    public var status: DTraceStatus {
        handle.status
    }

    // MARK: - Aggregations

    /// Takes a snapshot of aggregation data.
    public func snapshotAggregations() throws {
        try handle.aggregateSnap()
    }

    /// Prints aggregations to the configured output.
    public func printAggregations() throws {
        try handle.aggregateSnap()
        try outputDestination.withFilePointer { fp in
            try handle.aggregatePrint(to: fp)
        }
    }

    /// Prints aggregations to a specific output.
    public func printAggregations(to output: DTraceOutput) throws {
        try handle.aggregateSnap()
        try output.withFilePointer { fp in
            try handle.aggregatePrint(to: fp)
        }
    }

    /// Clears aggregation data.
    public func clearAggregations() {
        handle.aggregateClear()
    }

    // MARK: - Probe Discovery

    /// Lists probes matching a pattern.
    public func listProbes(matching pattern: String? = nil) throws -> [DTraceProbeDescription] {
        try handle.listProbes(matching: pattern)
    }

    /// Counts probes matching a pattern.
    public func countProbes(matching pattern: String? = nil) throws -> Int {
        try handle.countProbes(matching: pattern)
    }

    // MARK: - Internals

    private mutating func finalizeCurrentScript() {
        if let script = currentScript {
            scripts.append(script)
            currentScript = nil
        }
    }

    /// Returns all scripts that will be compiled.
    public func allScripts() -> [DTraceScript] {
        var result = scripts
        if let current = currentScript {
            result.append(current)
        }
        return result
    }

    /// Returns the combined D source code.
    public func buildSource() -> String {
        allScripts().map { $0.build() }.joined(separator: "\n\n")
    }
}
