/*
 * DProbes - Testing Infrastructure
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

// MARK: - Testing Strategy

/*
 * TESTING USDT PROBES
 * -------------------
 *
 * Testing DTrace probes presents unique challenges:
 * 1. Probes only fire when DTrace is attached (requires root)
 * 2. DTrace is a system-level tool, not easily mocked
 * 3. We want unit tests that run without root
 *
 * SOLUTION: DUAL-MODE TESTING
 *
 * 1. Unit Tests (no root required):
 *    - Use ProbeRecorder to intercept probe calls
 *    - Verify arguments are computed correctly
 *    - Test probe placement in code paths
 *
 * 2. Integration Tests (root required):
 *    - Actually run DTrace and verify probes fire
 *    - Parse DTrace output to verify arguments
 *    - Run as part of CI with elevated privileges
 */

// MARK: - ProbeRecorder

/// Records probe invocations for unit testing.
///
/// Use this to verify probes fire with correct arguments without
/// requiring DTrace or root privileges.
///
/// Example:
/// ```swift
/// func testRequestProbes() {
///     let recorder = ProbeRecorder()
///
///     ProbeRecorder.withRecording(recorder) {
///         handleRequest(mockRequest)
///     }
///
///     XCTAssertEqual(recorder.count(of: "webserver.request_start"), 1)
///
///     let probe = recorder.first(named: "webserver.request_start")!
///     XCTAssertEqual(probe.arg("path") as? String, "/api/users")
///     XCTAssertEqual(probe.arg("method") as? Int32, 1)
/// }
/// ```
public final class ProbeRecorder: @unchecked Sendable {
    /// A recorded probe invocation.
    public struct Invocation: Sendable {
        /// Full probe name (e.g., "webserver.request_start")
        public let probeName: String

        /// Timestamp of invocation
        public let timestamp: UInt64

        /// Arguments by name
        public let arguments: [String: any Sendable]

        /// Get argument by name
        public func arg(_ name: String) -> (any Sendable)? {
            arguments[name]
        }
    }

    private let lock = NSLock()
    private var _invocations: [Invocation] = []

    public init() {}

    /// All recorded invocations.
    public var invocations: [Invocation] {
        lock.lock()
        defer { lock.unlock() }
        return _invocations
    }

    /// Record a probe invocation.
    public func record(_ probeName: String, arguments: [String: any Sendable]) {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        let timestamp = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)

        lock.lock()
        defer { lock.unlock() }
        _invocations.append(Invocation(
            probeName: probeName,
            timestamp: timestamp,
            arguments: arguments
        ))
    }

    /// Clear all recorded invocations.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _invocations.removeAll()
    }

    /// Count of invocations for a specific probe.
    public func count(of probeName: String) -> Int {
        invocations.filter { $0.probeName == probeName }.count
    }

    /// First invocation of a specific probe.
    public func first(named probeName: String) -> Invocation? {
        invocations.first { $0.probeName == probeName }
    }

    /// All invocations of a specific probe.
    public func all(named probeName: String) -> [Invocation] {
        invocations.filter { $0.probeName == probeName }
    }

    /// Execute a block with probe recording enabled.
    ///
    /// During this block, all #probe invocations are intercepted
    /// and recorded instead of firing actual DTrace probes.
    ///
    /// - Note: Implementation pending macro support.
    public static func withRecording<T>(
        _ recorder: ProbeRecorder,
        _ body: () throws -> T
    ) rethrows -> T {
        // Store recorder for duration of block
        let previous = _currentRecorder
        _currentRecorder = recorder
        defer { _currentRecorder = previous }
        return try body()
    }

    /// Current recorder for interception (thread-local in future).
    /// - Note: Access is protected by withRecording's scoping.
    @usableFromInline
    nonisolated(unsafe) internal static var _currentRecorder: ProbeRecorder?
}

// MARK: - Integration Test Helpers

/// Helpers for running integration tests with actual DTrace.
///
/// These tests require root privileges and are typically run
/// separately from unit tests.
public enum DTraceTestHelpers {
    /// Check if we have DTrace capabilities (running as root).
    public static var canRunDTrace: Bool {
        getuid() == 0
    }

    /// Run a DTrace script and capture output.
    ///
    /// - Parameters:
    ///   - script: D script to run
    ///   - timeout: Maximum time to wait
    ///   - body: Code to execute while tracing
    /// - Returns: Captured DTrace output
    ///
    /// Example:
    /// ```swift
    /// let output = try DTraceTestHelpers.trace(
    ///     script: "webserver:::request_start { printf(\"%s\\n\", copyinstr(arg0)); }",
    ///     timeout: 5
    /// ) {
    ///     handleRequest(Request(path: "/test"))
    /// }
    /// XCTAssertTrue(output.contains("/test"))
    /// ```
    public static func trace(
        script: String,
        timeout: TimeInterval = 5,
        body: () throws -> Void
    ) throws -> String {
        guard canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        // Implementation:
        // 1. Start dtrace subprocess with script
        // 2. Wait for "dtrace: script ... matched N probes"
        // 3. Execute body
        // 4. Send SIGINT to dtrace
        // 5. Capture and return output

        fatalError("Implementation pending")
    }

    /// Verify a probe exists in the system.
    public static func probeExists(_ probeName: String) throws -> Bool {
        guard canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        // Run: dtrace -l -n 'probeName'
        // Check exit code

        fatalError("Implementation pending")
    }
}

/// Errors from DTrace test helpers.
public enum DTraceTestError: Error {
    case requiresRoot
    case dtraceNotFound
    case scriptFailed(String)
    case timeout
}

// MARK: - Test Assertions

/// Custom assertions for probe testing.
public enum ProbeAssertions {
    /// Assert a probe was invoked exactly N times.
    public static func assertProbeCount(
        _ recorder: ProbeRecorder,
        probe: String,
        equals expected: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let actual = recorder.count(of: probe)
        if actual != expected {
            // Would use XCTFail in actual implementation
            preconditionFailure(
                "Expected \(probe) to fire \(expected) times, but fired \(actual) times",
                file: file,
                line: line
            )
        }
    }

    /// Assert a probe was invoked with specific argument values.
    public static func assertProbeArgument<T: Equatable>(
        _ recorder: ProbeRecorder,
        probe: String,
        argument: String,
        equals expected: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let invocation = recorder.first(named: probe) else {
            preconditionFailure(
                "Probe \(probe) was never invoked",
                file: file,
                line: line
            )
        }
        guard let actual = invocation.arg(argument) as? T else {
            preconditionFailure(
                "Argument '\(argument)' not found or wrong type",
                file: file,
                line: line
            )
        }
        if actual != expected {
            preconditionFailure(
                "Expected \(probe).\(argument) to be \(expected), got \(actual)",
                file: file,
                line: line
            )
        }
    }
}

// MARK: - Mock Time Helper

/// Helper for testing latency probes with controlled time.
public struct MockClock {
    private var _now: UInt64 = 0

    public var now: UInt64 { _now }

    public mutating func advance(nanoseconds: UInt64) {
        _now += nanoseconds
    }

    public mutating func advance(milliseconds: UInt64) {
        _now += milliseconds * 1_000_000
    }

    public mutating func advance(seconds: UInt64) {
        _now += seconds * 1_000_000_000
    }
}
