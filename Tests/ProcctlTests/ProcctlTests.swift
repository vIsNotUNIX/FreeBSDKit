/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import Procctl

final class ProcctlTests: XCTestCase {

    // MARK: - ProcessTarget Tests

    func testProcessTargetCurrent() {
        let target = ProcessTarget.current
        XCTAssertEqual(target.id, 0)
    }

    func testProcessTargetPid() {
        let target = ProcessTarget.pid(1234)
        XCTAssertEqual(target.id, 1234)
    }

    func testProcessTargetProcessGroup() {
        let target = ProcessTarget.processGroup(5678)
        XCTAssertEqual(target.id, 5678)
    }

    // MARK: - Procctl.Error Tests

    func testErrorEquatable() {
        XCTAssertEqual(Procctl.Error.notPermitted, Procctl.Error.notPermitted)
        XCTAssertNotEqual(Procctl.Error.notPermitted, Procctl.Error.invalidArgument)
    }

    func testErrorDescription() {
        let error = Procctl.Error(errno: EPERM)
        XCTAssertFalse(error.description.isEmpty)
    }

    // MARK: - ASLR Tests

    func testASLRGetStatus() throws {
        let status = try Procctl.ASLR.getStatus()
        // Just verify we can read the status
        _ = status.isActive
        _ = status.isForceEnabled
        _ = status.isForceDisabled
        _ = status.isNoForce
    }

    func testASLRStatusProperties() {
        // PROC_ASLR_ACTIVE = 0x80000000
        let active = Procctl.ASLR.Status(rawValue: Int32(bitPattern: 0x80000000))
        XCTAssertTrue(active.isActive)

        let forceEnable = Procctl.ASLR.Status(rawValue: 1)
        XCTAssertTrue(forceEnable.isForceEnabled)

        let forceDisable = Procctl.ASLR.Status(rawValue: 2)
        XCTAssertTrue(forceDisable.isForceDisabled)

        let noForce = Procctl.ASLR.Status(rawValue: 3)
        XCTAssertTrue(noForce.isNoForce)
    }

    // MARK: - Trace Tests

    func testTraceGetStatus() throws {
        let status = try Procctl.Trace.getStatus()
        _ = status  // Just verify we can read it
    }

    func testTraceIsEnabled() throws {
        let enabled = try Procctl.Trace.isEnabled()
        // Default should be enabled for normal processes
        XCTAssertTrue(enabled)
    }

    func testTraceControlRawValues() {
        XCTAssertEqual(Procctl.Trace.Control.enable.rawValue, 1)
        XCTAssertEqual(Procctl.Trace.Control.disable.rawValue, 2)
        XCTAssertEqual(Procctl.Trace.Control.disableExec.rawValue, 3)
    }

    // MARK: - ProtMax Tests

    func testProtMaxGetStatus() throws {
        let status = try Procctl.ProtMax.getStatus()
        _ = status.isActive
        _ = status.isForceEnabled
        _ = status.isForceDisabled
        _ = status.isNoForce
    }

    // MARK: - StackGap Tests

    func testStackGapGetStatus() throws {
        let status = try Procctl.StackGap.getStatus()
        _ = status.isEnabled
        _ = status.enabledOnExec
        _ = status.disabledOnExec
    }

    // MARK: - NoNewPrivileges Tests

    func testNoNewPrivilegesIsEnabled() throws {
        let enabled = try Procctl.NoNewPrivileges.isEnabled()
        // Should be false by default
        XCTAssertFalse(enabled)
    }

    // MARK: - CapabilityTrap Tests

    func testCapabilityTrapIsEnabled() throws {
        let enabled = try Procctl.CapabilityTrap.isEnabled()
        // Should be false by default
        XCTAssertFalse(enabled)
    }

    // MARK: - ParentDeathSignal Tests

    func testParentDeathSignalGet() throws {
        let signal = try Procctl.ParentDeathSignal.get()
        // Should be nil by default
        XCTAssertNil(signal)
    }

    func testParentDeathSignalSetAndClear() throws {
        // Set a signal
        try Procctl.ParentDeathSignal.set(signal: SIGTERM)

        // Verify it was set
        let signal = try Procctl.ParentDeathSignal.get()
        XCTAssertEqual(signal, SIGTERM)

        // Clear it
        try Procctl.ParentDeathSignal.clear()

        // Verify it was cleared
        let cleared = try Procctl.ParentDeathSignal.get()
        XCTAssertNil(cleared)
    }

    // MARK: - WXMap Tests

    func testWXMapGetStatus() throws {
        let status = try Procctl.WXMap.getStatus()
        _ = status.isPermitted
        _ = status.isDisallowedExec
        _ = status.isEnforced
    }

    // MARK: - LogSigExit Tests

    func testLogSigExitGetStatus() throws {
        let status = try Procctl.LogSigExit.getStatus()
        _ = status.isNoForce
        _ = status.isForceEnabled
        _ = status.isForceDisabled
    }

    // MARK: - Reaper Tests

    func testReaperGetStatus() throws {
        let status = try Procctl.Reaper.getStatus()
        // Should not be a reaper by default (unless running as init)
        XCTAssertFalse(status.isReaper)
        // Note: childCount and descendantCount may be non-zero when running
        // under a test runner that spawns child processes
        _ = status.childCount
        _ = status.descendantCount
    }

    func testReaperStatusProperties() throws {
        let status = try Procctl.Reaper.getStatus()
        _ = status.isInit
        _ = status.reaperPid
        _ = status.pid
    }

    // MARK: - OOMProtection Options Tests

    func testOOMProtectionOptions() {
        let descend = Procctl.OOMProtection.Options.descend
        let inherit = Procctl.OOMProtection.Options.inherit
        let all = Procctl.OOMProtection.Options.all

        XCTAssertTrue(all.contains(descend))
        XCTAssertTrue(all.contains(inherit))
    }

    // MARK: - x86-specific Tests

    #if arch(x86_64)
    func testKPTIGetStatus() throws {
        let status = try Procctl.KPTI.getStatus()
        _ = status.isActive
    }

    func testLinearAddressGetStatus() throws {
        let status = try Procctl.LinearAddress.getStatus()
        // One of these should be true
        XCTAssertTrue(status.isLA48 || status.isLA57)
    }
    #endif
}
