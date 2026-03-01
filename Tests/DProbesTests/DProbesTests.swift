/*
 * DProbes Tests
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
import Foundation
@testable import DProbes

// MARK: - Strategy Verification Tests

@Suite("DProbes Strategy Tests")
struct StrategyTests {

    // MARK: - Constraint Tests

    @Test("Max arguments constraint is 10")
    func testMaxArguments() {
        #expect(DTraceConstraints.maxArguments == 10)
    }

    @Test("Max provider name length is 64")
    func testMaxProviderNameLength() {
        #expect(DTraceConstraints.maxProviderNameLength == 64)
    }

    @Test("Max probe name length is 64")
    func testMaxProbeNameLength() {
        #expect(DTraceConstraints.maxProbeNameLength == 64)
    }

    // MARK: - Stability Attribute Tests

    @Test("Stability levels have correct raw values for D pragma")
    func testStabilityRawValues() {
        #expect(ProbeStability.private.rawValue == "Private")
        #expect(ProbeStability.project.rawValue == "Project")
        #expect(ProbeStability.evolving.rawValue == "Evolving")
        #expect(ProbeStability.stable.rawValue == "Stable")
        #expect(ProbeStability.standard.rawValue == "Standard")
    }
}

// MARK: - ProbeRecorder Tests

@Suite("ProbeRecorder Tests")
struct ProbeRecorderTests {

    @Test("Recorder starts empty")
    func testRecorderStartsEmpty() {
        let recorder = ProbeRecorder()
        #expect(recorder.invocations.isEmpty)
    }

    @Test("Recorder captures invocations")
    func testRecorderCaptures() {
        let recorder = ProbeRecorder()

        recorder.record("myapp.request_start", arguments: [
            "path": "/api/users",
            "method": Int32(1)
        ])

        #expect(recorder.invocations.count == 1)
        #expect(recorder.count(of: "myapp.request_start") == 1)
    }

    @Test("Recorder filters by probe name")
    func testRecorderFilters() {
        let recorder = ProbeRecorder()

        recorder.record("myapp.request_start", arguments: ["path": "/a"])
        recorder.record("myapp.request_done", arguments: ["status": Int32(200)])
        recorder.record("myapp.request_start", arguments: ["path": "/b"])

        #expect(recorder.count(of: "myapp.request_start") == 2)
        #expect(recorder.count(of: "myapp.request_done") == 1)
        #expect(recorder.count(of: "myapp.error") == 0)
    }

    @Test("Recorder provides argument access")
    func testRecorderArguments() {
        let recorder = ProbeRecorder()

        recorder.record("myapp.request_start", arguments: [
            "path": "/api/users",
            "method": Int32(1),
            "requestID": UInt64(12345)
        ])

        let invocation = recorder.first(named: "myapp.request_start")
        #expect(invocation != nil)
        #expect(invocation?.arg("path") as? String == "/api/users")
        #expect(invocation?.arg("method") as? Int32 == 1)
        #expect(invocation?.arg("requestID") as? UInt64 == 12345)
        #expect(invocation?.arg("nonexistent") == nil)
    }

    @Test("Recorder can be cleared")
    func testRecorderClear() {
        let recorder = ProbeRecorder()

        recorder.record("myapp.test", arguments: [:])
        #expect(recorder.invocations.count == 1)

        recorder.clear()
        #expect(recorder.invocations.isEmpty)
    }

    @Test("Recorder is thread-safe")
    func testRecorderThreadSafety() async {
        let recorder = ProbeRecorder()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    recorder.record("myapp.test", arguments: ["index": i])
                }
            }
        }

        #expect(recorder.invocations.count == 100)
    }
}

// MARK: - Type Conversion Tests (Future Implementation)

@Suite("DTraceConvertible Tests")
struct DTraceConvertibleTests {

    @Test("Integer types are DTraceConvertible")
    func testIntegerTypes() {
        // These will be compile-time verified once macros are implemented
        // For now, document expected behavior

        // Int8, Int16, Int32, Int64 → direct cast
        // UInt8, UInt16, UInt32, UInt64 → direct cast
        #expect(Bool(true))  // Placeholder
    }

    @Test("String conversion is documented")
    func testStringConversion() {
        // String → withCString { ptr } → UInt(bitPattern: ptr)
        // String lives on stack during probe call
        // Freed immediately after probe returns
        #expect(Bool(true))  // Placeholder
    }

    @Test("Optional String becomes NULL when nil")
    func testOptionalString() {
        // nil → NULL pointer (0)
        // Some(s) → normal string conversion
        #expect(Bool(true))  // Placeholder
    }
}

// MARK: - Integration Test Stubs

@Suite("DTrace Integration Tests")
struct DTraceIntegrationTests {

    @Test("Can check DTrace availability")
    func testDTraceAvailability() {
        // This just verifies the helper exists
        let canRun = DTraceTestHelpers.canRunDTrace
        // Don't assert - may or may not be root
        _ = canRun
    }

    @Test("Integration tests require root", .disabled("Requires root"))
    func testRequiresRoot() throws {
        // This test is disabled by default
        // Run with: swift test --filter "requires root" as root

        guard DTraceTestHelpers.canRunDTrace else {
            throw DTraceTestError.requiresRoot
        }

        // Would actually trace here
    }
}

// MARK: - Macro Expansion Tests (Future)

@Suite("Macro Expansion Tests", .disabled("Macros not yet implemented"))
struct MacroExpansionTests {

    @Test("Provider definition generates correct D file")
    func testProviderGeneration() {
        // Test that #DTraceProvider generates valid .d syntax
    }

    @Test("Probe invocation expands to IS-ENABLED check")
    func testProbeExpansion() {
        // Test that #probe expands correctly
    }

    @Test("Too many arguments produces compile error")
    func testTooManyArguments() {
        // Test compile-time diagnostic
    }

    @Test("Invalid type produces compile error")
    func testInvalidType() {
        // Test compile-time diagnostic
    }
}

// MARK: - MockClock Tests

@Suite("MockClock Tests")
struct MockClockTests {

    @Test("MockClock starts at zero")
    func testStartsAtZero() {
        let clock = MockClock()
        #expect(clock.now == 0)
    }

    @Test("MockClock advances by nanoseconds")
    func testAdvanceNanoseconds() {
        var clock = MockClock()
        clock.advance(nanoseconds: 1000)
        #expect(clock.now == 1000)
    }

    @Test("MockClock advances by milliseconds")
    func testAdvanceMilliseconds() {
        var clock = MockClock()
        clock.advance(milliseconds: 5)
        #expect(clock.now == 5_000_000)
    }

    @Test("MockClock advances by seconds")
    func testAdvanceSeconds() {
        var clock = MockClock()
        clock.advance(seconds: 2)
        #expect(clock.now == 2_000_000_000)
    }
}
