/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import Foundation
import Glibc

/// A high-level interface for DTrace sessions using the DScript result builder.
///
/// `DScriptSession` wraps `DTraceHandle` and provides a guided experience
/// for building and running D programs using the type-safe `DScript` API.
///
/// ## Quick Start
///
/// For most use cases, use the static convenience methods:
///
/// ```swift
/// // Trace for 10 seconds, print results
/// try DScriptSession.trace(for: 10) {
///     Probe("syscall:::entry") {
///         Count(by: "probefunc")
///     }
/// }
///
/// // Capture output as a string
/// let output = try DScriptSession.capture(for: 5) {
///     Probe("syscall:::entry") {
///         Printf("%s: %s", "execname", "probefunc")
///     }
/// }
/// ```
///
/// ## Manual Control
///
/// For custom processing loops, use `start()`:
///
/// ```swift
/// var session = try DScriptSession.start {
///     Probe("syscall:::entry") {
///         Count(by: "probefunc")
///     }
/// }
///
/// // Custom loop with progress reporting
/// for i in 1...10 {
///     print("Second \(i)...")
///     let deadline = Date().addingTimeInterval(1)
///     while Date() < deadline && session.isRunning {
///         _ = session.process()
///         session.wait()
///     }
/// }
///
/// try session.stop()
/// try session.printAggregations()
/// ```
///
/// ## JSON Output
///
/// ```swift
/// var session = try DScriptSession.create()
/// try session.enableJSONOutput()
/// session.add { Probe("syscall:::entry") { Count(by: "probefunc") } }
/// try session.enable()
/// // ... process loop ...
/// try session.printAggregations()  // JSON formatted
/// ```
public struct DScriptSession: ~Copyable {
    private var handle: DTraceHandle
    private var scripts: [DScript] = []
    private var isStarted: Bool = false
    private var outputDestination: DTraceOutput = .stdout

    // MARK: - Initialization

    /// Creates a new DTrace session with configurable buffer sizes.
    ///
    /// The default buffer sizes of 4MB are appropriate for most tracing scenarios
    /// (libdtrace defaults are too small).
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
    ) throws -> DScriptSession {
        var session = DScriptSession(handle: try DTraceHandle.open(flags: flags))
        try session.handle.setOption("bufsize", value: traceBufferSize)
        try session.handle.setOption("aggsize", value: aggBufferSize)
        return session
    }

    private init(handle: consuming DTraceHandle) {
        self.handle = handle
    }

    /// Traces using the provided script until it exits, printing all output.
    ///
    /// This is the simplest way to run a DTrace script. It handles everything:
    /// creating the session, enabling probes, processing output, and printing
    /// aggregations when done.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    ///
    /// try DScriptSession.trace(script)  // That's it!
    /// ```
    public static func trace(_ script: DScript) throws {
        var session = try create()
        session.add(script)
        try session.enable()
        while session.process() == .okay {
            session.wait()
        }
        try session.printAggregations()
    }

    /// Traces using a script builder until it exits, printing all output.
    ///
    /// ```swift
    /// try DScriptSession.trace {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(10, .seconds) { Exit(0) }
    /// }
    /// ```
    public static func trace(@DScriptBuilder _ builder: () -> [ProbeClause]) throws {
        try trace(DScript(builder))
    }

    /// Traces for a specific duration, printing all output.
    ///
    /// ```swift
    /// try DScriptSession.trace(for: 30) {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    public static func trace(
        for seconds: TimeInterval,
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws {
        try trace(DScript(builder), for: seconds)
    }

    /// Traces a script for a specific duration, printing all output.
    public static func trace(_ script: DScript, for seconds: TimeInterval) throws {
        var session = try create()
        session.add(script)
        try session.enable()

        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if session.process() != .okay { break }
            session.wait()
        }
        try session.stop()
        try session.printAggregations()
    }

    /// Traces and captures all output as a string.
    ///
    /// ```swift
    /// let output = try DScriptSession.capture {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    ///     Tick(5, .seconds) { Exit(0) }
    /// }
    /// print(output)
    /// ```
    public static func capture(
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try capture(DScript(builder))
    }

    /// Traces a script and captures all output as a string.
    public static func capture(_ script: DScript) throws -> String {
        let buffer = DTraceOutputBuffer()
        var session = try create()
        session.output(to: .buffer(buffer))
        session.add(script)
        try session.enable()

        while session.process() == .okay {
            session.wait()
        }
        try session.printAggregations()
        return buffer.contents
    }

    /// Traces for a duration and captures all output as a string.
    ///
    /// ```swift
    /// let output = try DScriptSession.capture(for: 30) {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    public static func capture(
        for seconds: TimeInterval,
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> String {
        try capture(DScript(builder), for: seconds)
    }

    /// Traces a script for a duration and captures all output as a string.
    public static func capture(_ script: DScript, for seconds: TimeInterval) throws -> String {
        let buffer = DTraceOutputBuffer()
        var session = try create()
        session.output(to: .buffer(buffer))
        session.add(script)
        try session.enable()

        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if session.process() != .okay { break }
            session.wait()
        }
        try session.stop()
        try session.printAggregations()
        return buffer.contents
    }

    // MARK: - Manual Session Creation (Advanced)

    /// Creates a session with the script added and enabled, ready for manual control.
    ///
    /// Use this when you need custom control over the processing loop.
    /// For simple cases, prefer `trace()` or `capture()`.
    ///
    /// ```swift
    /// var session = try DScriptSession.start(script)
    ///
    /// // Custom processing loop
    /// for i in 1...10 {
    ///     print("Second \(i)...")
    ///     let deadline = Date().addingTimeInterval(1)
    ///     while Date() < deadline {
    ///         if session.process() != .okay { break }
    ///         session.wait()
    ///     }
    /// }
    ///
    /// try session.stop()
    /// try session.printAggregations()
    /// ```
    public static func start(_ script: DScript) throws -> DScriptSession {
        var session = try create()
        session.add(script)
        try session.enable()
        return session
    }

    /// Creates a session with a script builder, added and enabled.
    public static func start(
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> DScriptSession {
        try start(DScript(builder))
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

    // MARK: - Adding Scripts

    /// Adds a DScript to the session.
    ///
    /// ```swift
    /// var session = try DScriptSession.create()
    ///
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Target(.execname("nginx"))
    ///         Count(by: "probefunc")
    ///     }
    /// }
    ///
    /// session.add(script)
    /// try session.start()
    /// ```
    public mutating func add(_ script: DScript) {
        scripts.append(script)
    }

    /// Adds a script using a result builder.
    ///
    /// ```swift
    /// var session = try DScriptSession.create()
    /// session.add {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// try session.start()
    /// ```
    public mutating func add(@DScriptBuilder _ builder: () -> [ProbeClause]) {
        scripts.append(DScript(builder))
    }

    // MARK: - Predefined Scripts

    /// Adds a syscall counting script.
    public mutating func syscallCounts(for target: DTraceTarget = .all) {
        scripts.append(.syscallCounts(for: target))
    }

    /// Adds a file open tracing script.
    public mutating func fileOpens(for target: DTraceTarget = .all) {
        scripts.append(.fileOpens(for: target))
    }

    /// Adds a CPU profiling script.
    public mutating func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) {
        scripts.append(.cpuProfile(hz: hz, for: target))
    }

    /// Adds an I/O bytes tracking script.
    public mutating func ioBytes(for target: DTraceTarget = .all) {
        scripts.append(.ioBytes(for: target))
    }

    /// Adds a syscall latency measurement script.
    public mutating func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) {
        scripts.append(.syscallLatency(syscall, for: target))
    }

    /// Adds a process exec tracing script.
    public mutating func processExec() {
        scripts.append(.processExec())
    }

    // MARK: - Execution

    /// Compiles and enables the tracing session.
    ///
    /// This compiles all added scripts and enables the probes in the kernel.
    /// After calling this, probes will fire and data will accumulate.
    /// Use `process()` in a loop to consume data.
    ///
    /// - Throws: Any compilation or execution errors.
    public mutating func enable() throws {
        for script in scripts {
            let source = script.source
            let program = try handle.compile(source)
            try handle.exec(program)
        }

        try handle.go()
        isStarted = true
    }


    /// Stops tracing and disables all probes.
    ///
    /// Most users don't need to call this directly - `runToCompletion()` and
    /// `runFor(seconds:)` handle stopping automatically.
    public func stop() throws {
        try handle.stop()
    }

    /// The current session status.
    public var status: DTraceStatus {
        handle.status
    }

    /// Whether tracing is still running.
    ///
    /// Returns `false` when the script has exited (via `Exit()` action) or been stopped.
    public var isRunning: Bool {
        isStarted && status != .stopped
    }

    // MARK: - Low-Level Methods (For Custom Control)

    /// Processes available trace data without blocking.
    ///
    /// **Most users should use `runToCompletion()` or `runFor(seconds:)` instead.**
    ///
    /// This is for advanced use cases requiring custom control flow.
    /// Returns the current status:
    /// - `.okay` - Data processed, call again
    /// - `.done` - Script exited (via `Exit()` action)
    /// - `.error` - An error occurred
    public func process() -> DTraceWorkStatus {
        outputDestination.withFilePointer { fp in
            handle.poll(to: fp)
        }
    }

    /// Blocks until the kernel has trace data available.
    ///
    /// **Most users should use `runToCompletion()` or `runFor(seconds:)` instead.**
    ///
    /// Use between `process()` calls for efficient waiting.
    public func wait() {
        handle.sleep()
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

    /// Lists all available DTrace providers on the system.
    ///
    /// This queries the kernel for all probes and extracts the unique provider names.
    ///
    /// - Returns: Array of provider names sorted alphabetically.
    public func listProviders() throws -> [String] {
        let probes = try handle.listProbes(matching: nil)
        let providers = Set(probes.map { $0.provider })
        return providers.sorted()
    }

    // MARK: - JSON Output

    /// Enables JSON structured output for this session.
    ///
    /// When enabled, trace output (printf, aggregations, etc.) will be formatted
    /// as JSON instead of plain text. This uses DTrace's native `oformat` option.
    ///
    /// Call this before `start()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var session = try DScriptSession.create()
    /// try session.enableJSONOutput()
    ///
    /// let buffer = DTraceOutputBuffer()
    /// session.output(to: .buffer(buffer))
    ///
    /// session.add {
    ///     Probe("syscall:::entry") { Count(by: "probefunc") }
    /// }
    ///
    /// try session.start()
    /// // ... run trace ...
    /// try session.printAggregations()
    ///
    /// let json = buffer.contents  // JSON-formatted aggregation data
    /// ```
    ///
    /// - Throws: `DTraceCoreError.setOptFailed` if JSON mode cannot be enabled.
    ///
    /// - Note: This is different from `DScript.jsonString` which outputs the
    ///   script's AST as JSON. This method formats the actual trace output as JSON.
    public mutating func enableJSONOutput() throws {
        try handle.enableStructuredOutput()
    }

    /// Whether JSON structured output is enabled.
    ///
    /// Returns `true` if `enableJSONOutput()` was called and JSON mode is active.
    public var isJSONOutputEnabled: Bool {
        handle.isStructuredOutputEnabled
    }

    /// Disables JSON structured output, returning to plain text mode.
    ///
    /// Call this after `stop()` if you want to switch back to text output.
    public mutating func disableJSONOutput() {
        handle.disableStructuredOutput()
    }

    // MARK: - Process Targeting

    /// Attaches to an existing process for tracing.
    ///
    /// This allows you to use `$target` and `.pid($target)` in scripts.
    /// The process is stopped when attached; call `continue()` to resume it.
    ///
    /// ## Example
    /// ```swift
    /// var session = try DScriptSession.create()
    /// let proc = try session.attach(to: 1234)
    ///
    /// session.add {
    ///     Probe("syscall:::entry") {
    ///         Target(.pid("$target"))  // Only trace attached process
    ///         Count(by: "probefunc")
    ///     }
    /// }
    ///
    /// try session.start()
    /// proc.continue()  // Resume the stopped process
    ///
    /// while session.poll() == .okay { session.sleep() }
    /// ```
    ///
    /// - Parameter pid: The process ID to attach to.
    /// - Returns: A process handle for controlling the attached process.
    /// - Throws: `DTraceCoreError.procGrabFailed` if attachment fails.
    public func attach(to pid: pid_t) throws -> DTraceHandle.ProcessHandle {
        try handle.grabProcess(pid: pid)
    }

    /// Creates and launches a new process under DTrace control.
    ///
    /// The process is created in a stopped state. Use `$target` in scripts,
    /// then call `continue()` on the returned handle to start the process.
    ///
    /// ## Example
    /// ```swift
    /// var session = try DScriptSession.create()
    /// let proc = try session.spawn(
    ///     path: "/usr/local/bin/myapp",
    ///     arguments: ["myapp", "--verbose"]
    /// )
    ///
    /// session.add {
    ///     Probe("syscall:::entry") {
    ///         Target(.pid("$target"))
    ///         Count(by: "probefunc")
    ///     }
    /// }
    ///
    /// try session.start()
    /// proc.continue()  // Start the process
    ///
    /// while session.poll() == .okay { session.sleep() }
    /// ```
    ///
    /// - Parameters:
    ///   - path: Path to the executable.
    ///   - arguments: Command-line arguments (including argv[0]).
    /// - Returns: A process handle for controlling the spawned process.
    /// - Throws: `DTraceCoreError.procCreateFailed` if spawn fails.
    public func spawn(
        path: String,
        arguments: [String] = []
    ) throws -> DTraceHandle.ProcessHandle {
        try handle.createProcess(path: path, arguments: arguments)
    }

    // MARK: - Introspection

    /// Returns all scripts that will be compiled.
    public var allScripts: [DScript] {
        scripts
    }

    /// Returns the combined D source code.
    public var source: String {
        scripts.map { $0.source }.joined(separator: "\n\n")
    }
}
