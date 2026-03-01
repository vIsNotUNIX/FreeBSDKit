/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import Glibc

/// A high-level interface for DTrace sessions using the DScript result builder.
///
/// `DScriptSession` wraps `DTraceHandle` and provides a guided experience
/// for building and running D programs using the type-safe `DScript` API.
///
/// ## Basic Example
///
/// ```swift
/// let script = DScript {
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         Count(by: "probefunc")
///     }
/// }
///
/// var session = try DScriptSession.create()
/// session.add(script)
/// try session.start()
///
/// while session.poll() == .okay {
///     session.sleep()
/// }
///
/// try session.printAggregations()
/// ```
///
/// ## JSON Output
///
/// DTrace supports native JSON output for aggregations and trace data:
///
/// ```swift
/// var session = try DScriptSession.create()
/// try session.enableJSONOutput()  // Enable JSON mode
///
/// session.add(script)
/// try session.start()
///
/// // Output will now be JSON formatted
/// while session.poll() == .okay { session.sleep() }
/// try session.printAggregations()
///
/// session.disableJSONOutput()  // Back to text mode
/// ```
///
/// ## Output Capture
///
/// Capture output to a buffer for programmatic processing:
///
/// ```swift
/// let buffer = DTraceOutputBuffer()
/// session.output(to: .buffer(buffer))
///
/// try session.start()
/// // ... trace ...
/// try session.printAggregations()
///
/// let output = buffer.contents  // Get captured text/JSON
/// ```
public struct DScriptSession: ~Copyable {
    private var handle: DTraceHandle
    private var scripts: [DScript] = []
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
    ) throws -> DScriptSession {
        var session = try DScriptSession(flags: flags)
        try session.handle.setOption("bufsize", value: traceBufferSize)
        try session.handle.setOption("aggsize", value: aggBufferSize)
        return session
    }

    /// Creates a session and runs the provided DScript.
    ///
    /// A convenience initializer for running a single DScript.
    ///
    /// ```swift
    /// let script = DScript {
    ///     Probe("syscall:::entry") {
    ///         Count(by: "probefunc")
    ///     }
    /// }
    ///
    /// var session = try DScriptSession.run(script)
    /// // Session is already started
    /// ```
    public static func run(
        _ script: DScript,
        flags: DTraceOpenFlags = [],
        traceBufferSize: String = "4m",
        aggBufferSize: String = "4m"
    ) throws -> DScriptSession {
        var session = try create(
            flags: flags,
            traceBufferSize: traceBufferSize,
            aggBufferSize: aggBufferSize
        )
        session.add(script)
        try session.start()
        return session
    }

    /// Creates a session using a result builder and starts it.
    ///
    /// ```swift
    /// var session = try DScriptSession.run {
    ///     Probe("syscall:::entry") {
    ///         Target(.execname("nginx"))
    ///         Count(by: "probefunc")
    ///     }
    /// }
    /// ```
    public static func run(
        flags: DTraceOpenFlags = [],
        traceBufferSize: String = "4m",
        aggBufferSize: String = "4m",
        @DScriptBuilder _ builder: () -> [ProbeClause]
    ) throws -> DScriptSession {
        let script = DScript(builder)
        return try run(
            script,
            flags: flags,
            traceBufferSize: traceBufferSize,
            aggBufferSize: aggBufferSize
        )
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

    /// Compiles and starts the tracing session.
    ///
    /// - Throws: Any compilation or execution errors.
    public mutating func start() throws {
        for script in scripts {
            let source = script.source
            let program = try handle.compile(source)
            try handle.exec(program)
        }

        try handle.go()
        isStarted = true
    }

    /// Processes available trace data.
    ///
    /// Call this repeatedly in a loop until it returns `.done` or `.error`.
    /// Each call processes whatever data is currently available and writes
    /// it to the configured output destination.
    ///
    /// - Returns: `.okay` to continue polling, `.done` when tracing finished, `.error` on failure.
    ///
    /// ## Example
    /// ```swift
    /// try session.start()
    /// while session.poll() == .okay {
    ///     session.sleep()
    /// }
    /// ```
    public func poll() -> DTraceWorkStatus {
        outputDestination.withFilePointer { fp in
            handle.poll(to: fp)
        }
    }

    /// Processes available trace data to a specific output.
    ///
    /// - Parameter output: Where to write the output.
    /// - Returns: `.okay` to continue polling, `.done` when tracing finished, `.error` on failure.
    public func poll(to output: DTraceOutput) -> DTraceWorkStatus {
        output.withFilePointer { fp in
            handle.poll(to: fp)
        }
    }

    /// Deprecated: Use `poll()` instead.
    @available(*, deprecated, renamed: "poll()")
    public func work() -> DTraceWorkStatus {
        poll()
    }

    /// Deprecated: Use `poll(to:)` instead.
    @available(*, deprecated, renamed: "poll(to:)")
    public func work(to output: DTraceOutput) -> DTraceWorkStatus {
        poll(to: output)
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
