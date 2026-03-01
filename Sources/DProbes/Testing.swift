/*
 * DProbes - Testing Infrastructure
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

// MARK: - Wait Status Helpers

@inlinable
func wifExited(_ status: Int32) -> Bool {
    (status & 0x7F) == 0
}

@inlinable
func wExitStatus(_ status: Int32) -> Int32 {
    (status >> 8) & 0xFF
}

// MARK: - ProbeRecorder

/// Records probe invocations for testing.
///
/// **Note:** Must be manually integrated - generated probe code does not
/// automatically call the recorder. For actual probe verification, use
/// `DTraceTestHelpers.trace()` which runs real DTrace.
public final class ProbeRecorder: @unchecked Sendable {
    public struct Invocation: Sendable {
        public let probeName: String
        public let timestamp: UInt64
        public let arguments: [String: any Sendable]

        public func arg(_ name: String) -> (any Sendable)? {
            arguments[name]
        }
    }

    private let lock = NSLock()
    private var _invocations: [Invocation] = []

    public init() {}

    public var invocations: [Invocation] {
        lock.lock()
        defer { lock.unlock() }
        return _invocations
    }

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

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _invocations.removeAll()
    }

    public func count(of probeName: String) -> Int {
        invocations.filter { $0.probeName == probeName }.count
    }

    public func first(named probeName: String) -> Invocation? {
        invocations.first { $0.probeName == probeName }
    }

    public func all(named probeName: String) -> [Invocation] {
        invocations.filter { $0.probeName == probeName }
    }
}

// MARK: - DTrace Test Helpers

/// Helpers for running integration tests with actual DTrace (requires root).
public enum DTraceTestHelpers {
    public static var canRunDTrace: Bool {
        getuid() == 0
    }

    /// Run a DTrace script and capture output while executing body.
    public static func trace(
        script: String,
        timeout: TimeInterval = 5,
        body: () throws -> Void
    ) throws -> String {
        guard canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        var stdoutPipe: [Int32] = [0, 0]
        var stderrPipe: [Int32] = [0, 0]
        pipe(&stdoutPipe)
        pipe(&stderrPipe)

        let pid = fork()
        if pid == 0 {
            close(stdoutPipe[0])
            close(stderrPipe[0])
            dup2(stdoutPipe[1], STDOUT_FILENO)
            dup2(stderrPipe[1], STDERR_FILENO)
            close(stdoutPipe[1])
            close(stderrPipe[1])

            let args = ["dtrace", "-q", "-n", script]
            var cArgs = args.map { strdup($0) }
            cArgs.append(nil)
            execv("/usr/sbin/dtrace", &cArgs)
            _exit(1)
        }

        guard pid > 0 else {
            throw DTraceTestError.scriptFailed("Failed to fork")
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])

        usleep(500_000)  // Wait for dtrace to start

        do {
            try body()
        } catch {
            kill(pid, SIGINT)
            throw error
        }

        usleep(100_000)
        kill(pid, SIGINT)

        var status: Int32 = 0
        let startTime = Date()
        var finished = false

        while Date().timeIntervalSince(startTime) < timeout {
            let result = waitpid(pid, &status, WNOHANG)
            if result == pid {
                finished = true
                break
            }
            usleep(10_000)
        }

        if !finished {
            kill(pid, SIGKILL)
            waitpid(pid, &status, 0)
            throw DTraceTestError.timeout
        }

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(stdoutPipe[0], &buffer, buffer.count)
            if bytesRead <= 0 { break }
            output.append(contentsOf: buffer[0..<bytesRead])
        }
        close(stdoutPipe[0])
        close(stderrPipe[0])

        return String(data: output, encoding: .utf8) ?? ""
    }

    /// Check if a probe exists (requires root).
    public static func probeExists(_ probeName: String) throws -> Bool {
        guard canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        var stdoutPipe: [Int32] = [0, 0]
        pipe(&stdoutPipe)

        let pid = fork()
        if pid == 0 {
            close(stdoutPipe[0])
            dup2(stdoutPipe[1], STDOUT_FILENO)
            dup2(stdoutPipe[1], STDERR_FILENO)
            close(stdoutPipe[1])

            let args = ["dtrace", "-l", "-n", probeName]
            var cArgs = args.map { strdup($0) }
            cArgs.append(nil)
            execv("/usr/sbin/dtrace", &cArgs)
            _exit(1)
        }

        guard pid > 0 else {
            throw DTraceTestError.scriptFailed("Failed to fork")
        }

        close(stdoutPipe[1])

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        close(stdoutPipe[0])

        return wifExited(status) && wExitStatus(status) == 0
    }

    /// List probes matching a pattern (requires root).
    public static func listProbes(matching pattern: String) throws -> [String] {
        guard canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        var stdoutPipe: [Int32] = [0, 0]
        pipe(&stdoutPipe)

        let pid = fork()
        if pid == 0 {
            close(stdoutPipe[0])
            dup2(stdoutPipe[1], STDOUT_FILENO)
            close(stdoutPipe[1])

            let args = ["dtrace", "-l", "-n", pattern]
            var cArgs = args.map { strdup($0) }
            cArgs.append(nil)
            execv("/usr/sbin/dtrace", &cArgs)
            _exit(1)
        }

        guard pid > 0 else {
            throw DTraceTestError.scriptFailed("Failed to fork")
        }

        close(stdoutPipe[1])

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(stdoutPipe[0], &buffer, buffer.count)
            if bytesRead <= 0 { break }
            output.append(contentsOf: buffer[0..<bytesRead])
        }
        close(stdoutPipe[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        guard let text = String(data: output, encoding: .utf8) else {
            return []
        }

        return text.split(separator: "\n")
            .dropFirst()
            .compactMap { line -> String? in
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                guard parts.count >= 5 else { return nil }
                return "\(parts[1]):\(parts[2]):\(parts[3]):\(parts[4])"
            }
    }
}

// MARK: - Errors

public enum DTraceTestError: Error {
    case requiresRoot
    case dtraceNotFound
    case scriptFailed(String)
    case timeout
}

// MARK: - Assertions

public enum ProbeAssertions {
    public static func assertProbeCount(
        _ recorder: ProbeRecorder,
        probe: String,
        equals expected: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let actual = recorder.count(of: probe)
        if actual != expected {
            preconditionFailure(
                "Expected \(probe) to fire \(expected) times, but fired \(actual) times",
                file: file,
                line: line
            )
        }
    }

    public static func assertProbeArgument<T: Equatable>(
        _ recorder: ProbeRecorder,
        probe: String,
        argument: String,
        equals expected: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let invocation = recorder.first(named: probe) else {
            preconditionFailure("Probe \(probe) was never invoked", file: file, line: line)
        }
        guard let actual = invocation.arg(argument) as? T else {
            preconditionFailure("Argument '\(argument)' not found or wrong type", file: file, line: line)
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

// MARK: - MockClock

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
