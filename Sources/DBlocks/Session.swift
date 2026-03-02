/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import Foundation
import Glibc

/// A DTrace tracing session.
///
/// `DTraceSession` wraps `DTraceHandle` and provides a clean interface
/// for configuring and running DTrace scripts.
///
/// ## Quick Start
///
/// For simple cases, use `DBlocks.run()` directly:
///
/// ```swift
/// try DBlocks.run {
///     Probe("syscall:::entry") { Count() }
///     Tick(5, .seconds) { Exit(0) }
/// }
/// ```
///
/// ## Configured Sessions
///
/// Use `DTraceSession` when you need custom configuration:
///
/// ```swift
/// let buffer = DTraceOutputBuffer()
///
/// var session = try DTraceSession.create()
/// session.output(to: .buffer(buffer))
/// try session.bufferSize("8m")
/// try session.jsonOutput()
///
/// session.add {
///     Probe("syscall:::entry") { Count(by: "probefunc") }
/// }
///
/// try session.run(for: 10)
/// print(buffer.contents)
/// ```
///
/// ## Manual Control
///
/// For custom processing loops:
///
/// ```swift
/// var session = try DTraceSession.create()
/// session.add {
///     Probe("syscall:::entry") { Count(by: "probefunc") }
/// }
/// try session.start()
///
/// for i in 1...10 {
///     print("Second \(i)...")
///     session.process(for: 1.0)
/// }
///
/// try session.stop()
/// try session.printAggregations()
/// ```
public struct DTraceSession: ~Copyable {
    private var handle: DTraceHandle
    private var scripts: [DBlocks] = []
    private var isEnabled: Bool = false
    private var outputDestination: DTraceOutput = .stdout

    // MARK: - Initialization

    /// Creates a new DTrace session.
    ///
    /// ```swift
    /// var session = try DTraceSession.create()
    /// ```
    ///
    /// - Parameter flags: Optional flags for opening the DTrace handle.
    /// - Throws: `DTraceCoreError.openFailed` if the session cannot be created.
    public static func create(flags: DTraceOpenFlags = []) throws -> DTraceSession {
        var handle = try DTraceHandle.open(flags: flags)
        // Set reasonable defaults (libdtrace defaults are too small)
        try handle.setOption("bufsize", value: "4m")
        try handle.setOption("aggsize", value: "4m")
        return DTraceSession(handle: handle)
    }

    private init(handle: consuming DTraceHandle) {
        self.handle = handle
    }

    // MARK: - Configuration

    /// Sets the output destination.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.output(to: .buffer(buffer))
    /// ```
    public mutating func output(to destination: DTraceOutput) {
        outputDestination = destination
    }

    /// Sets the trace buffer size.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// try session.bufferSize("8m")
    /// ```
    public mutating func bufferSize(_ size: String) throws {
        try handle.setOption("bufsize", value: size)
    }

    /// Sets the aggregation buffer size.
    public mutating func aggBufferSize(_ size: String) throws {
        try handle.setOption("aggsize", value: size)
    }

    /// Enables quiet mode (suppresses default output).
    public mutating func quiet() throws {
        try handle.setOption("quiet")
    }

    /// Enables JSON structured output.
    ///
    /// When enabled, trace output (printf, aggregations, etc.) will be
    /// formatted as JSON instead of plain text.
    public mutating func jsonOutput() throws {
        try handle.enableStructuredOutput()
    }

    /// Sets a DTrace option.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// try session.option("flowindent")
    /// try session.option("stackframes", value: "100")
    /// ```
    public mutating func option(_ name: String, value: String? = nil) throws {
        try handle.setOption(name, value: value)
    }

    // MARK: - Adding Scripts

    /// Adds a script to the session.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.add(script)
    /// ```
    public mutating func add(_ script: DBlocks) {
        scripts.append(script)
    }

    /// Adds a script using a result builder.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.add {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    public mutating func add(@DBlocksBuilder _ builder: () -> [ProbeClause]) {
        scripts.append(DBlocks(builder))
    }

    // MARK: - Execution (Simple)

    /// Runs all added scripts until they exit (via `Exit()` action).
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.add {
    ///     Probe("syscall:::entry") { Count() }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    /// try session.run()
    /// ```
    public mutating func run() throws {
        try start()
        while process() == .okay {
            wait()
        }
        try printAggregations()
    }

    /// Runs all added scripts for a specific duration.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.add {
    ///     Probe("syscall:::entry") { Count() }
    /// }
    /// try session.run(for: 10)  // 10 seconds
    /// ```
    public mutating func run(for seconds: TimeInterval) throws {
        try start()
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if process() != .okay { break }
            wait()
        }
        try stop()
        try printAggregations()
    }

    // MARK: - Execution (Manual Control)

    /// Compiles and enables all added scripts.
    ///
    /// After calling this, probes will fire and data will accumulate.
    /// Use `process()` to consume data.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// session.add { ... }
    /// try session.start()
    ///
    /// while session.isRunning {
    ///     _ = session.process()
    ///     session.wait()
    /// }
    /// ```
    public mutating func start() throws {
        for script in scripts {
            let program = try handle.compile(script.source)
            try handle.exec(program)
        }
        try handle.go()
        isEnabled = true
    }

    /// Stops tracing and disables all probes.
    public func stop() throws {
        try handle.stop()
    }

    /// Processes available trace data without blocking.
    ///
    /// Returns the current status:
    /// - `.okay` - Data processed, call again
    /// - `.done` - Script exited (via `Exit()` action)
    /// - `.error` - An error occurred
    public func process() -> DTraceWorkStatus {
        outputDestination.withFilePointer { fp in
            handle.poll(to: fp)
        }
    }

    /// Processes trace data for a specific duration.
    ///
    /// ```swift
    /// for i in 1...10 {
    ///     print("Second \(i)...")
    ///     session.process(for: 1.0)
    /// }
    /// ```
    public func process(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if process() != .okay { break }
            wait()
        }
    }

    /// Blocks until the kernel has trace data available.
    public func wait() {
        handle.sleep()
    }

    /// The current session status.
    public var status: DTraceStatus {
        handle.status
    }

    /// Whether tracing is still running.
    public var isRunning: Bool {
        isEnabled && status != .stopped
    }

    /// Whether JSON structured output is enabled.
    public var isJSONOutputEnabled: Bool {
        handle.isStructuredOutputEnabled
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
    ///
    /// ```swift
    /// let probes = try session.listProbes(matching: "syscall:::entry")
    /// ```
    public func listProbes(matching pattern: String? = nil) throws -> [DTraceProbeDescription] {
        try handle.listProbes(matching: pattern)
    }

    /// Counts probes matching a pattern.
    public func countProbes(matching pattern: String? = nil) throws -> Int {
        try handle.countProbes(matching: pattern)
    }

    /// Lists all available DTrace providers.
    public func listProviders() throws -> [String] {
        let probes = try handle.listProbes(matching: nil)
        return Set(probes.map { $0.provider }).sorted()
    }

    // MARK: - Process Targeting

    /// Attaches to an existing process for tracing.
    ///
    /// This allows you to use `$target` in scripts.
    /// The process is stopped when attached; call `continue()` to resume.
    ///
    /// ```swift
    /// var session = try DTraceSession()
    /// let proc = try session.attach(to: 1234)
    ///
    /// session.add {
    ///     Probe("syscall:::entry") {
    ///         When("pid == $target")
    ///         Count()
    ///     }
    /// }
    ///
    /// try session.start()
    /// proc.continue()
    /// ```
    public func attach(to pid: pid_t) throws -> DTraceHandle.ProcessHandle {
        try handle.grabProcess(pid: pid)
    }

    /// Creates and launches a new process under DTrace control.
    ///
    /// The process is created stopped. Use `$target` in scripts,
    /// then call `continue()` to start the process.
    public func spawn(path: String, arguments: [String] = []) throws -> DTraceHandle.ProcessHandle {
        try handle.createProcess(path: path, arguments: arguments)
    }

    // MARK: - Introspection

    /// Returns all scripts added to this session.
    public var allScripts: [DBlocks] {
        scripts
    }

    /// Returns the combined D source code.
    public var source: String {
        scripts.map { $0.source }.joined(separator: "\n\n")
    }
}

// MARK: - Deprecated Compatibility

/// Deprecated: Use `DTraceSession` instead.
@available(*, deprecated, renamed: "DTraceSession")
public typealias DBlocksSession = DTraceSession
