/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CDTrace
import Glibc

/// A handle to an open DTrace session.
///
/// `DTraceHandle` is a move-only type that owns the underlying libdtrace handle.
/// When the handle is deinitialized, the DTrace session is automatically closed.
///
/// This is the raw, low-level API. For a fluent builder API, see `DTraceBuilder.DTraceSession`.
///
/// ## Example
///
/// ```swift
/// let handle = try DTraceHandle.open()
/// let program = try handle.compile("""
///     syscall:::entry /execname == "nginx"/ {
///         @[probefunc] = count();
///     }
///     """)
/// try handle.exec(program)
/// try handle.go()
///
/// while handle.work() == .okay {
///     handle.sleep()
/// }
/// ```
public struct DTraceHandle: ~Copyable {
    @usableFromInline
    internal var _handle: OpaquePointer?

    /// Opens a new DTrace handle.
    ///
    /// - Parameter flags: Flags controlling how the handle is opened.
    /// - Returns: A new DTrace handle.
    /// - Throws: `DTraceCoreError.openFailed` if the handle cannot be opened.
    /// - Note: Requires appropriate privileges (typically root).
    public static func open(flags: DTraceOpenFlags = []) throws -> DTraceHandle {
        var err: Int32 = 0
        guard let hdl = cdtrace_open(cdtrace_version(), flags.rawValue, &err) else {
            let msg = String(cString: dtrace_errmsg(nil, err))
            throw DTraceCoreError.openFailed(code: err, message: msg)
        }
        return DTraceHandle(_handle: hdl)
    }

    @usableFromInline
    internal init(_handle: OpaquePointer) {
        self._handle = _handle
    }

    deinit {
        if let h = _handle {
            cdtrace_close(h)
        }
    }

    /// Provides scoped access to the underlying handle for advanced usage.
    ///
    /// - Parameter body: A closure that receives the raw handle pointer.
    /// - Returns: The value returned by the closure.
    /// - Throws: `DTraceCoreError.invalidHandle` if the handle is invalid.
    @inlinable
    public func withUnsafeHandle<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard let h = _handle else {
            throw DTraceCoreError.invalidHandle
        }
        return try body(h)
    }

    // MARK: - Error Handling

    /// Gets the last error code from this handle.
    public var lastError: Int32 {
        guard let h = _handle else { return 0 }
        return cdtrace_errno(h)
    }

    /// Gets the error message for the last error.
    public var lastErrorMessage: String {
        guard let h = _handle else { return "Invalid handle" }
        let err = cdtrace_errno(h)
        return String(cString: cdtrace_errmsg(h, err))
    }

    /// Gets the error message for a specific error code.
    public func errorMessage(for code: Int32) -> String {
        guard let h = _handle else { return "Invalid handle" }
        return String(cString: cdtrace_errmsg(h, code))
    }

    // MARK: - Options

    /// Sets a DTrace option.
    ///
    /// - Parameters:
    ///   - option: The option name (e.g., "bufsize", "quiet", "flowindent").
    ///   - value: The option value, or nil for boolean options.
    /// - Throws: `DTraceCoreError.setOptFailed` if the option cannot be set.
    public func setOption(_ option: String, value: String? = nil) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let result = option.withCString { optPtr in
            if let v = value {
                return v.withCString { valPtr in
                    cdtrace_setopt(h, optPtr, valPtr)
                }
            } else {
                return cdtrace_setopt(h, optPtr, nil)
            }
        }

        if result != 0 {
            throw DTraceCoreError.setOptFailed(option: option, message: lastErrorMessage)
        }
    }

    /// Gets a DTrace option value.
    ///
    /// - Parameter option: The option name.
    /// - Returns: The option value.
    /// - Throws: `DTraceCoreError.getOptFailed` if the option cannot be retrieved.
    public func getOption(_ option: String) throws -> Int64 {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        var value: dtrace_optval_t = 0
        let result = option.withCString { optPtr in
            cdtrace_getopt(h, optPtr, &value)
        }

        if result != 0 {
            throw DTraceCoreError.getOptFailed(option: option, message: lastErrorMessage)
        }

        return value
    }

    // MARK: - Program Compilation

    /// Compiles a D program from a string.
    ///
    /// - Parameters:
    ///   - source: The D program source code.
    ///   - flags: Compilation flags.
    /// - Returns: A compiled program that can be executed.
    /// - Throws: `DTraceCoreError.compileFailed` if compilation fails.
    public func compile(
        _ source: String,
        flags: DTraceCompileFlags = []
    ) throws -> DTraceProgram {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let program = source.withCString { srcPtr in
            cdtrace_program_strcompile(
                h,
                srcPtr,
                DTRACE_PROBESPEC_NAME,
                flags.rawValue,
                0,
                nil
            )
        }

        guard let prog = program else {
            throw DTraceCoreError.compileFailed(message: lastErrorMessage)
        }

        return DTraceProgram(program: prog)
    }

    /// Executes a compiled D program, enabling its probes.
    ///
    /// - Parameter program: The compiled program to execute.
    /// - Returns: Information about the executed program.
    /// - Throws: `DTraceCoreError.execFailed` if execution fails.
    @discardableResult
    public func exec(_ program: borrowing DTraceProgram) throws -> DTraceProgramInfo {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        var info = dtrace_proginfo_t()
        let result = cdtrace_program_exec(h, program.unsafeProgram(), &info)

        if result != 0 {
            throw DTraceCoreError.execFailed(message: lastErrorMessage)
        }

        return DTraceProgramInfo(from: info)
    }

    // MARK: - Tracing Control

    /// Starts tracing.
    ///
    /// - Throws: `DTraceCoreError.goFailed` if tracing cannot be started.
    public func go() throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let result = cdtrace_go(h)
        if result != 0 {
            throw DTraceCoreError.goFailed(message: lastErrorMessage)
        }
    }

    /// Stops tracing.
    ///
    /// - Throws: `DTraceCoreError.stopFailed` if tracing cannot be stopped.
    public func stop() throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let result = cdtrace_stop(h)
        if result != 0 {
            throw DTraceCoreError.stopFailed(message: lastErrorMessage)
        }
    }

    /// Waits for data to be available.
    public func sleep() {
        guard let h = _handle else { return }
        cdtrace_sleep(h)
    }

    /// Gets the current status of the DTrace session.
    public var status: DTraceStatus {
        guard let h = _handle else { return .stopped }
        return DTraceStatus(from: cdtrace_status(h))
    }

    // MARK: - Data Consumption

    /// Processes available trace data, writing to stdout.
    ///
    /// - Returns: The work status indicating whether to continue processing.
    public func work() -> DTraceWorkStatus {
        work(to: Glibc.stdout)
    }

    /// Processes available trace data with a custom output file.
    ///
    /// - Parameter file: The FILE pointer to write output to.
    /// - Returns: The work status indicating whether to continue processing.
    public func work(to file: UnsafeMutablePointer<FILE>) -> DTraceWorkStatus {
        guard let h = _handle else { return .error }
        let status = cdtrace_work(h, file, nil, nil, nil)
        return DTraceWorkStatus(from: status)
    }

    /// Consume result for record callbacks.
    public enum ConsumeResult: Int32, Sendable {
        case error = -1   // Error while processing
        case this = 0     // Consume this probe/record
        case next = 1     // Advance to next probe/record
        case abort = 2    // Abort consumption
    }

    /// Data from a probe firing.
    public struct ProbeData: Sendable {
        public let cpu: Int32
        public let probe: DTraceProbeDescription
    }

    /// Consumes trace data with custom callbacks.
    ///
    /// This provides more control than `work()` by letting you handle
    /// each probe firing and record individually.
    ///
    /// - Parameter probeCallback: Called for each probe that fires.
    ///                            Return `.this` to process records, `.next` to skip.
    /// - Throws: `DTraceCoreError.consumeFailed` if consumption fails.
    public func consume(
        _ probeCallback: @escaping (ProbeData) -> ConsumeResult
    ) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        var context = ConsumeContext(probeCallback: probeCallback)

        let result = withUnsafeMutablePointer(to: &context) { ctxPtr in
            cdtrace_consume(h, Glibc.stdout, consumeProbeCallback, nil, ctxPtr)
        }

        if result < 0 {
            throw DTraceCoreError.consumeFailed(message: lastErrorMessage)
        }
    }

    // MARK: - Aggregations

    /// Takes a snapshot of all aggregation data.
    ///
    /// - Throws: `DTraceCoreError.aggregateFailed` if the snapshot fails.
    public func aggregateSnap() throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let result = cdtrace_aggregate_snap(h)
        if result != 0 {
            throw DTraceCoreError.aggregateFailed(message: lastErrorMessage)
        }
    }

    /// Prints all aggregation data to stdout.
    ///
    /// - Throws: `DTraceCoreError.aggregateFailed` if printing fails.
    public func aggregatePrint() throws {
        try aggregatePrint(to: Glibc.stdout)
    }

    /// Prints all aggregation data to a file.
    ///
    /// - Parameter file: The FILE pointer to write to.
    /// - Throws: `DTraceCoreError.aggregateFailed` if printing fails.
    public func aggregatePrint(to file: UnsafeMutablePointer<FILE>) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        let result = cdtrace_aggregate_print(h, file, nil)
        if result != 0 {
            throw DTraceCoreError.aggregateFailed(message: lastErrorMessage)
        }
    }

    /// Clears all aggregation data.
    public func aggregateClear() {
        guard let h = _handle else { return }
        cdtrace_aggregate_clear(h)
    }

    // MARK: - Aggregation Walking

    /// The result of processing an aggregation record.
    public enum AggregateWalkResult: Int32, Sendable {
        case next = 0       // Proceed to next element
        case abort = 1      // Abort aggregation walk
        case clear = 2      // Clear this element
        case remove = 5     // Remove this element
    }

    /// Walks through aggregation data programmatically.
    ///
    /// This allows you to access aggregation data directly instead of
    /// just printing it.
    ///
    /// - Parameters:
    ///   - sorted: If true, walks in sorted order (by value).
    ///   - callback: Called for each aggregation record with raw data pointer and size.
    ///               Return `.next` to continue, `.abort` to stop.
    /// - Throws: `DTraceCoreError.aggregateFailed` if walk fails.
    public func aggregateWalk(
        sorted: Bool = true,
        _ callback: @escaping (UnsafeRawPointer, Int) -> AggregateWalkResult
    ) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        var context = AggregateWalkContext(callback: callback)

        let result = withUnsafeMutablePointer(to: &context) { ctxPtr in
            if sorted {
                return cdtrace_aggregate_walk_sorted(h, aggregateWalkCallback, ctxPtr)
            } else {
                return cdtrace_aggregate_walk(h, aggregateWalkCallback, ctxPtr)
            }
        }

        if result < 0 {
            throw DTraceCoreError.aggregateFailed(message: lastErrorMessage)
        }
    }

    // MARK: - Probe Iteration

    /// Iterates over all available probes matching a pattern.
    ///
    /// - Parameters:
    ///   - pattern: A probe pattern like "syscall:::entry" or nil for all probes.
    ///   - callback: Called for each matching probe. Return `true` to continue.
    /// - Throws: `DTraceCoreError.probeIterFailed` if iteration fails.
    public func iterateProbes(
        matching pattern: String? = nil,
        _ callback: @escaping (DTraceProbeDescription) -> Bool
    ) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        var context = ProbeIterContext(callback: callback, userAborted: false)

        let result = withUnsafeMutablePointer(to: &context) { ctxPtr in
            if let pattern = pattern {
                var pdesc = dtrace_probedesc_t()
                return pattern.withCString { patternPtr in
                    let parseResult = dtrace_str2desc(h, DTRACE_PROBESPEC_NAME, patternPtr, &pdesc)
                    if parseResult == 0 {
                        return cdtrace_probe_iter(h, &pdesc, probeIterCallback, ctxPtr)
                    } else {
                        // Pattern parsing failed, iterate all probes
                        return cdtrace_probe_iter(h, nil, probeIterCallback, ctxPtr)
                    }
                }
            } else {
                return cdtrace_probe_iter(h, nil, probeIterCallback, ctxPtr)
            }
        }

        // result < 0 means actual error, result > 0 means callback stopped iteration
        // Only throw for actual errors (result < 0)
        if result < 0 {
            throw DTraceCoreError.probeIterFailed(message: lastErrorMessage)
        }
    }

    /// Returns the number of available probes.
    ///
    /// - Parameter pattern: A probe pattern to filter, or nil for all probes.
    public func countProbes(matching pattern: String? = nil) throws -> Int {
        var count = 0
        try iterateProbes(matching: pattern) { _ in
            count += 1
            return true
        }
        return count
    }

    /// Returns all probes matching a pattern as an array.
    ///
    /// - Parameter pattern: A probe pattern to filter, or nil for all probes.
    /// - Note: This can be memory-intensive for large numbers of probes.
    public func listProbes(matching pattern: String? = nil) throws -> [DTraceProbeDescription] {
        var probes: [DTraceProbeDescription] = []
        try iterateProbes(matching: pattern) { probe in
            probes.append(probe)
            return true
        }
        return probes
    }

    // MARK: - Handlers

    /// Information about a drop event.
    public struct DropInfo: Sendable {
        public let kind: DropKind
        public let drops: UInt64
        public let message: String
    }

    /// The type of data that was dropped.
    public enum DropKind: Int32, Sendable {
        case principal = 0      // Drop to principal buffer
        case aggregation = 1    // Drop to aggregation buffer
        case dynamic = 2        // Dynamic drop
        case speculation = 5    // Speculative drop
        case unknown = -1
    }

    /// Information about an error event.
    public struct ErrorInfo: Sendable {
        public let fault: Int32
        public let message: String
    }

    /// Sets a handler for error events.
    ///
    /// - Parameter handler: Called when an error occurs. Return `true` to continue, `false` to abort.
    /// - Throws: `DTraceCoreError.handlerFailed` if the handler cannot be set.
    public func onError(_ handler: @escaping (ErrorInfo) -> Bool) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        // Store callback in global storage for C callback access
        _errorHandler = handler

        let result = cdtrace_handle_err(h, errorHandlerCallback, nil)
        if result != 0 {
            throw DTraceCoreError.handlerFailed(message: lastErrorMessage)
        }
    }

    /// Sets a handler for drop events (when data is dropped due to buffer overflow).
    ///
    /// - Parameter handler: Called when data is dropped. Return `true` to continue, `false` to abort.
    /// - Throws: `DTraceCoreError.handlerFailed` if the handler cannot be set.
    public func onDrop(_ handler: @escaping (DropInfo) -> Bool) throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        _dropHandler = handler

        let result = cdtrace_handle_drop(h, dropHandlerCallback, nil)
        if result != 0 {
            throw DTraceCoreError.handlerFailed(message: lastErrorMessage)
        }
    }

    // MARK: - Process Control

    /// A handle to a process being traced.
    public struct ProcessHandle: ~Copyable {
        @usableFromInline
        internal var _proc: OpaquePointer?
        @usableFromInline
        internal var _dtrace: OpaquePointer?

        internal init(proc: OpaquePointer, dtrace: OpaquePointer) {
            self._proc = proc
            self._dtrace = dtrace
        }

        deinit {
            if let p = _proc, let d = _dtrace {
                cdtrace_proc_release(d, p)
            }
        }

        /// Continues execution of the attached process.
        public func `continue`() {
            guard let p = _proc, let d = _dtrace else { return }
            cdtrace_proc_continue(d, p)
        }
    }

    /// Attaches to an existing process for tracing.
    ///
    /// This allows you to use `$target` in D scripts to reference the attached process.
    ///
    /// - Parameters:
    ///   - pid: The process ID to attach to.
    ///   - flags: Flags for process grabbing.
    /// - Returns: A process handle for the attached process.
    /// - Throws: `DTraceCoreError.procGrabFailed` if the process cannot be attached.
    public func grabProcess(pid: pid_t, flags: Int32 = 0) throws -> ProcessHandle {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        guard let proc = cdtrace_proc_grab(h, pid, flags) else {
            throw DTraceCoreError.procGrabFailed(pid: pid, message: lastErrorMessage)
        }

        return ProcessHandle(proc: proc, dtrace: h)
    }

    /// Updates the process cache (call after process state changes).
    public func updateProcessCache() {
        guard let h = _handle else { return }
        cdtrace_update(h)
    }

    // MARK: - Output Format

    /// Output format mode.
    public enum OutputFormat: Int32, Sendable {
        case text = 0        // Plain text output (default)
        case structured = 1  // JSON/XML structured output
    }

    /// Configures structured output (JSON) mode.
    ///
    /// When enabled, output will be in JSON format instead of plain text.
    /// Must be called before `go()`.
    ///
    /// - Throws: `DTraceCoreError.setOptFailed` if configuration fails.
    public func enableStructuredOutput() throws {
        guard let h = _handle else { throw DTraceCoreError.invalidHandle }

        // Set oformat option to structured
        try setOption("oformat", value: "json")

        let result = cdtrace_oformat_configure(h)
        if result != 0 {
            throw DTraceCoreError.setOptFailed(option: "oformat", message: lastErrorMessage)
        }

        cdtrace_oformat_setup(h)
    }

    /// Checks if structured output is enabled.
    public var isStructuredOutputEnabled: Bool {
        guard let h = _handle else { return false }
        return cdtrace_oformat(h) == CDTRACE_OFORMAT_STRUCTURED.rawValue
    }

    /// Tears down structured output mode.
    public func disableStructuredOutput() {
        guard let h = _handle else { return }
        cdtrace_oformat_teardown(h)
    }
}

// MARK: - Probe Iteration Internals

private struct ProbeIterContext {
    var callback: (DTraceProbeDescription) -> Bool
    var userAborted: Bool
}

private func probeIterCallback(
    _ dtp: OpaquePointer?,
    _ pdp: UnsafePointer<dtrace_probedesc_t>?,
    _ arg: UnsafeMutableRawPointer?
) -> Int32 {
    guard let arg = arg, let pdp = pdp else {
        // No more probes or invalid args - return 0 to signal normal completion
        return 0
    }

    let context = arg.assumingMemoryBound(to: ProbeIterContext.self)

    let probe = DTraceProbeDescription(
        id: cdtrace_probedesc_id(pdp),
        provider: String(cString: cdtrace_probedesc_provider(pdp)),
        module: String(cString: cdtrace_probedesc_mod(pdp)),
        function: String(cString: cdtrace_probedesc_func(pdp)),
        name: String(cString: cdtrace_probedesc_name(pdp))
    )

    if context.pointee.callback(probe) {
        return 0  // Continue iteration
    } else {
        context.pointee.userAborted = true
        return 1  // Stop iteration (user requested)
    }
}

// MARK: - Aggregation Walk Internals

private struct AggregateWalkContext {
    var callback: (UnsafeRawPointer, Int) -> DTraceHandle.AggregateWalkResult
}

private func aggregateWalkCallback(
    _ data: UnsafePointer<dtrace_aggdata_t>?,
    _ arg: UnsafeMutableRawPointer?
) -> Int32 {
    guard let arg = arg, let data = data else {
        return DTRACE_AGGWALK_NEXT
    }

    let context = arg.assumingMemoryBound(to: AggregateWalkContext.self)

    let rawData = cdtrace_aggdata_data(data)
    let size = cdtrace_aggdata_size(data)

    guard let ptr = rawData else {
        return DTRACE_AGGWALK_NEXT
    }

    let result = context.pointee.callback(UnsafeRawPointer(ptr), size)
    return result.rawValue
}

// MARK: - Handler Internals

// Global storage for handlers (required for C callbacks)
// Note: These are marked nonisolated(unsafe) because C callbacks cannot use Swift actors.
// The handlers are only set from the main thread before tracing starts.
nonisolated(unsafe) private var _errorHandler: ((DTraceHandle.ErrorInfo) -> Bool)?
nonisolated(unsafe) private var _dropHandler: ((DTraceHandle.DropInfo) -> Bool)?

private func errorHandlerCallback(
    _ data: UnsafePointer<dtrace_errdata_t>?,
    _ arg: UnsafeMutableRawPointer?
) -> Int32 {
    guard let data = data, let handler = _errorHandler else {
        return DTRACE_HANDLE_OK
    }

    let msg = String(cString: cdtrace_errdata_msg(data))
    let fault = cdtrace_errdata_fault(data)

    let info = DTraceHandle.ErrorInfo(fault: fault, message: msg)

    return handler(info) ? DTRACE_HANDLE_OK : DTRACE_HANDLE_ABORT
}

private func dropHandlerCallback(
    _ data: UnsafePointer<dtrace_dropdata_t>?,
    _ arg: UnsafeMutableRawPointer?
) -> Int32 {
    guard let data = data, let handler = _dropHandler else {
        return DTRACE_HANDLE_OK
    }

    let kindRaw = cdtrace_dropdata_kind(data)
    let kind = DTraceHandle.DropKind(rawValue: Int32(kindRaw.rawValue)) ?? .unknown
    let drops = cdtrace_dropdata_drops(data)
    let msg = String(cString: cdtrace_dropdata_msg(data))

    let info = DTraceHandle.DropInfo(kind: kind, drops: drops, message: msg)

    return handler(info) ? DTRACE_HANDLE_OK : DTRACE_HANDLE_ABORT
}

// MARK: - Consume Internals

private struct ConsumeContext {
    var probeCallback: (DTraceHandle.ProbeData) -> DTraceHandle.ConsumeResult
}

private func consumeProbeCallback(
    _ data: UnsafePointer<dtrace_probedata_t>?,
    _ arg: UnsafeMutableRawPointer?
) -> Int32 {
    guard let data = data, let arg = arg else {
        return DTRACE_CONSUME_NEXT
    }

    let context = arg.assumingMemoryBound(to: ConsumeContext.self)

    let cpu = cdtrace_probedata_cpu(data)
    let pdesc = cdtrace_probedata_pdesc(data)

    let probe: DTraceProbeDescription
    if let pdesc = pdesc {
        probe = DTraceProbeDescription(
            id: cdtrace_probedesc_id(pdesc),
            provider: String(cString: cdtrace_probedesc_provider(pdesc)),
            module: String(cString: cdtrace_probedesc_mod(pdesc)),
            function: String(cString: cdtrace_probedesc_func(pdesc)),
            name: String(cString: cdtrace_probedesc_name(pdesc))
        )
    } else {
        probe = DTraceProbeDescription(id: 0, provider: "", module: "", function: "", name: "")
    }

    let probeData = DTraceHandle.ProbeData(cpu: cpu, probe: probe)
    let result = context.pointee.probeCallback(probeData)

    return result.rawValue
}
