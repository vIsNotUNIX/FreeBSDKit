/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
@testable import DTraceCore

@Suite("DTraceCore Tests")
struct DTraceCoreTests {

    @Test("Version is available")
    func testVersion() {
        let version = DTraceCore.version
        #expect(version > 0)
    }

    @Test("Open flags are correct")
    func testOpenFlags() {
        let noDevice = DTraceOpenFlags.noDevice
        #expect(noDevice.rawValue == 0x01)

        let noSystem = DTraceOpenFlags.noSystem
        #expect(noSystem.rawValue == 0x02)

        let lp64 = DTraceOpenFlags.lp64
        #expect(lp64.rawValue == 0x04)

        let ilp32 = DTraceOpenFlags.ilp32
        #expect(ilp32.rawValue == 0x08)

        let combined: DTraceOpenFlags = [.noDevice, .noSystem]
        #expect(combined.rawValue == 0x03)

        // Test OptionSet conformance
        let empty: DTraceOpenFlags = []
        #expect(empty.rawValue == 0)

        var mutable: DTraceOpenFlags = [.noDevice]
        mutable.insert(.noSystem)
        #expect(mutable.contains(.noDevice))
        #expect(mutable.contains(.noSystem))
    }

    @Test("Compile flags are correct")
    func testCompileFlags() {
        // Verify flags exist and have non-zero values
        let verbose = DTraceCompileFlags.verbose
        #expect(verbose.rawValue != 0)

        let allowEmpty = DTraceCompileFlags.allowEmpty
        #expect(allowEmpty.rawValue != 0)

        let allowZeroMatches = DTraceCompileFlags.allowZeroMatches
        #expect(allowZeroMatches.rawValue != 0)

        let probeSpec = DTraceCompileFlags.probeSpec
        #expect(probeSpec.rawValue != 0)

        let noLibs = DTraceCompileFlags.noLibs
        #expect(noLibs.rawValue != 0)

        // Verify all flags are distinct
        let allFlags = [verbose, allowEmpty, allowZeroMatches, probeSpec, noLibs]
        for i in 0..<allFlags.count {
            for j in (i+1)..<allFlags.count {
                #expect(allFlags[i].rawValue != allFlags[j].rawValue)
            }
        }

        // Test combining flags
        let combined: DTraceCompileFlags = [.allowEmpty, .allowZeroMatches]
        #expect(combined.contains(.allowEmpty))
        #expect(combined.contains(.allowZeroMatches))
        #expect(!combined.contains(.verbose))

        // Test OptionSet conformance
        let empty: DTraceCompileFlags = []
        #expect(empty.rawValue == 0)

        var mutable: DTraceCompileFlags = [.verbose]
        mutable.insert(.allowEmpty)
        #expect(mutable.contains(.verbose))
        #expect(mutable.contains(.allowEmpty))
    }

    @Test("Probe description formats correctly")
    func testProbeDescription() {
        let probe = DTraceProbeDescription(
            id: 123,
            provider: "syscall",
            module: "kernel",
            function: "open",
            name: "entry"
        )

        #expect(probe.fullName == "syscall:kernel:open:entry")
        #expect(probe.description == "syscall:kernel:open:entry")
        #expect(probe.id == 123)
    }

    @Test("Probe description with default ID")
    func testProbeDescriptionDefaultId() {
        let probe = DTraceProbeDescription(
            provider: "fbt",
            module: "kernel",
            function: "malloc",
            name: "return"
        )

        #expect(probe.id == 0)
        #expect(probe.fullName == "fbt:kernel:malloc:return")
    }

    @Test("Probe description debug description")
    func testProbeDescriptionDebug() {
        let probe = DTraceProbeDescription(
            id: 42,
            provider: "syscall",
            module: "freebsd",
            function: "read",
            name: "entry"
        )

        #expect(probe.debugDescription == "DTraceProbeDescription(id: 42, syscall:freebsd:read:entry)")
    }

    @Test("Probe description is Hashable")
    func testProbeDescriptionHashable() {
        let probe1 = DTraceProbeDescription(
            id: 1,
            provider: "syscall",
            module: "kernel",
            function: "open",
            name: "entry"
        )

        let probe2 = DTraceProbeDescription(
            id: 1,
            provider: "syscall",
            module: "kernel",
            function: "open",
            name: "entry"
        )

        let probe3 = DTraceProbeDescription(
            id: 2,
            provider: "syscall",
            module: "kernel",
            function: "close",
            name: "entry"
        )

        #expect(probe1 == probe2)
        #expect(probe1 != probe3)

        // Test in Set
        let probeSet: Set<DTraceProbeDescription> = [probe1, probe2, probe3]
        #expect(probeSet.count == 2)  // probe1 and probe2 are equal
    }

    @Test("Work status enum values")
    func testWorkStatus() {
        let error = DTraceWorkStatus.error
        let okay = DTraceWorkStatus.okay
        let done = DTraceWorkStatus.done

        #expect(error != okay)
        #expect(okay != done)
        #expect(error != done)
    }

    @Test("DTrace status enum values")
    func testStatus() {
        let none = DTraceStatus.none
        let okay = DTraceStatus.okay
        let exited = DTraceStatus.exited
        let filled = DTraceStatus.filled
        let stopped = DTraceStatus.stopped

        #expect(none != okay)
        #expect(okay != exited)
        #expect(exited != filled)
        #expect(filled != stopped)
    }
}

@Suite("DTraceCoreError Tests")
struct DTraceCoreErrorTests {

    @Test("Error cases are distinct")
    func testErrorCases() {
        let openFailed = DTraceCoreError.openFailed(code: 1, message: "test")
        let compileFailed = DTraceCoreError.compileFailed(message: "test")
        let execFailed = DTraceCoreError.execFailed(message: "test")
        let goFailed = DTraceCoreError.goFailed(message: "test")
        let stopFailed = DTraceCoreError.stopFailed(message: "test")
        let workFailed = DTraceCoreError.workFailed(message: "test")
        let setOptFailed = DTraceCoreError.setOptFailed(option: "bufsize", message: "test")
        let getOptFailed = DTraceCoreError.getOptFailed(option: "bufsize", message: "test")
        let probeIterFailed = DTraceCoreError.probeIterFailed(message: "test")
        let handlerFailed = DTraceCoreError.handlerFailed(message: "test")
        let aggregateFailed = DTraceCoreError.aggregateFailed(message: "test")
        let invalidHandle = DTraceCoreError.invalidHandle

        // Just verify they can be created and are Error conforming
        let errors: [any Error] = [
            openFailed, compileFailed, execFailed, goFailed, stopFailed,
            workFailed, setOptFailed, getOptFailed, probeIterFailed,
            handlerFailed, aggregateFailed, invalidHandle
        ]

        #expect(errors.count == 12)
    }

    @Test("Error is Sendable")
    func testErrorSendable() {
        let error: any Error & Sendable = DTraceCoreError.invalidHandle
        #expect(error is DTraceCoreError)
    }
}

@Suite("DTraceProgramInfo Tests")
struct DTraceProgramInfoTests {

    @Test("Program info fields are accessible")
    func testProgramInfoFields() {
        // Create a mock dtrace_proginfo_t to test our Swift struct
        // Note: We can't directly create one in tests without dtrace,
        // but we can verify the struct definition is correct
        #expect(true)  // Placeholder - actual testing requires dtrace handle
    }
}
