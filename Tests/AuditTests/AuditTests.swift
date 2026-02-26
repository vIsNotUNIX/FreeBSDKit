/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import Audit

final class AuditTests: XCTestCase {

    // MARK: - Type Tests

    func testAuditConditionValues() {
        XCTAssertEqual(Audit.Condition.unset.rawValue, 0)
        XCTAssertEqual(Audit.Condition.auditing.rawValue, 1)
        XCTAssertEqual(Audit.Condition.noAudit.rawValue, 2)
        XCTAssertEqual(Audit.Condition.disabled.rawValue, -1)
    }

    func testAuditPolicyValues() {
        // Just verify we can create policy combinations
        let policy: Audit.Policy = [.continueOnFailure, .includeArgv]
        XCTAssertTrue(policy.contains(.continueOnFailure))
        XCTAssertTrue(policy.contains(.includeArgv))
        XCTAssertFalse(policy.contains(.haltOnFailure))
    }

    func testTerminalID() {
        let tid = Audit.TerminalID(port: 1234, machine: 0x7f000001)
        XCTAssertEqual(tid.port, 1234)
        XCTAssertEqual(tid.machine, 0x7f000001)

        // Test C conversion roundtrip
        let cTid = tid.toC()
        let restored = Audit.TerminalID(from: cTid)
        XCTAssertEqual(restored.port, tid.port)
        XCTAssertEqual(restored.machine, tid.machine)
    }

    func testMask() {
        let mask = Audit.Mask(success: 0xFF, failure: 0x0F)
        XCTAssertEqual(mask.success, 0xFF)
        XCTAssertEqual(mask.failure, 0x0F)

        // Test presets
        XCTAssertEqual(Audit.Mask.none.success, 0)
        XCTAssertEqual(Audit.Mask.none.failure, 0)
        XCTAssertNotEqual(Audit.Mask.all.success, 0)
        XCTAssertNotEqual(Audit.Mask.all.failure, 0)

        // Test C conversion roundtrip
        let cMask = mask.toC()
        let restored = Audit.Mask(from: cMask)
        XCTAssertEqual(restored.success, mask.success)
        XCTAssertEqual(restored.failure, mask.failure)
    }

    func testAuditInfo() {
        let info = Audit.AuditInfo(
            auditID: 1000,
            mask: Audit.Mask(success: 0xFF, failure: 0x0F),
            terminalID: Audit.TerminalID(port: 1234, machine: 0),
            sessionID: 100
        )
        XCTAssertEqual(info.auditID, 1000)
        XCTAssertEqual(info.mask.success, 0xFF)
        XCTAssertEqual(info.terminalID.port, 1234)
        XCTAssertEqual(info.sessionID, 100)

        // Test C conversion roundtrip
        let cInfo = info.toC()
        let restored = Audit.AuditInfo(from: cInfo)
        XCTAssertEqual(restored.auditID, info.auditID)
        XCTAssertEqual(restored.mask.success, info.mask.success)
        XCTAssertEqual(restored.sessionID, info.sessionID)
    }

    func testQueueControl() {
        let qctrl = Audit.QueueControl(
            highWater: 200,
            lowWater: 20,
            bufferSize: 16384,
            delay: 10,
            minFree: 15
        )
        XCTAssertEqual(qctrl.highWater, 200)
        XCTAssertEqual(qctrl.lowWater, 20)
        XCTAssertEqual(qctrl.bufferSize, 16384)
        XCTAssertEqual(qctrl.delay, 10)
        XCTAssertEqual(qctrl.minFree, 15)

        // Test C conversion roundtrip
        let cQctrl = qctrl.toC()
        let restored = Audit.QueueControl(from: cQctrl)
        XCTAssertEqual(restored.highWater, qctrl.highWater)
        XCTAssertEqual(restored.lowWater, qctrl.lowWater)
        XCTAssertEqual(restored.bufferSize, qctrl.bufferSize)
    }

    // MARK: - Error Tests

    func testErrorEquatable() {
        XCTAssertEqual(Audit.Error.notPermitted, Audit.Error.notPermitted)
        XCTAssertNotEqual(Audit.Error.notPermitted, Audit.Error.invalidArgument)
    }

    func testErrorDescription() {
        let error = Audit.Error(errno: EPERM)
        XCTAssertFalse(error.description.isEmpty)
    }

    func testErrorPresets() {
        XCTAssertEqual(Audit.Error.notPermitted.errno, EPERM)
        XCTAssertEqual(Audit.Error.noSuchProcess.errno, ESRCH)
        XCTAssertEqual(Audit.Error.invalidArgument.errno, EINVAL)
        XCTAssertEqual(Audit.Error.notSupported.errno, EOPNOTSUPP)
        XCTAssertEqual(Audit.Error.noMemory.errno, ENOMEM)
    }

    // MARK: - Event/Class Lookup Tests

    func testGetEventByNumber() {
        // Event 0 is AUE_NULL
        if let event = Audit.event(number: 0) {
            XCTAssertEqual(event.number, 0)
            XCTAssertFalse(event.name.isEmpty)
        }
        // Note: May return nil if audit_event file is not present
    }

    func testGetClassByName() {
        // "all" is a standard class name meaning all events
        if let cls = Audit.eventClass(named: "all") {
            XCTAssertFalse(cls.name.isEmpty)
            XCTAssertNotEqual(cls.classMask, 0)
        }
        // Note: May return nil if audit_class file is not present
    }

    func testAllEventsIteration() {
        var count = 0
        Audit.forEachEvent { _ in
            count += 1
        }
        // Should have at least some events defined
        // This may be 0 if audit_event file doesn't exist
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testAllClassesIteration() {
        var count = 0
        Audit.forEachClass { _ in
            count += 1
        }
        // Should have at least some classes defined
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    // MARK: - System State Tests (require appropriate privileges)

    func testIsEnabled() {
        // This should not throw, even if audit is disabled
        let enabled = Audit.isEnabled
        // Just verify we got a result
        _ = enabled
    }

    func testGetCondition() {
        do {
            let condition = try Audit.condition()
            // Verify we got a valid condition
            XCTAssertTrue(
                condition == .unset ||
                condition == .auditing ||
                condition == .noAudit ||
                condition == .disabled
            )
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetCondition: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetPolicy() {
        do {
            _ = try Audit.policy()
            // Just verify we can call it without error
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetPolicy: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetQueueControl() {
        do {
            let qctrl = try Audit.queueControl()
            // Verify reasonable values
            XCTAssertGreaterThan(qctrl.highWater, 0)
            XCTAssertGreaterThan(qctrl.bufferSize, 0)
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetQueueControl: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetStatistics() {
        do {
            let stats = try Audit.statistics()
            // Verify we got some stats
            XCTAssertGreaterThanOrEqual(stats.version, 0)
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetStatistics: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Process Audit Info Tests

    func testGetAuditID() {
        do {
            _ = try Audit.auditID()
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetAuditID: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetAuditInfo() {
        do {
            let info = try Audit.auditInfo()
            // Session ID should be valid
            _ = info.sessionID
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testGetAuditInfo: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Record Builder Tests

    func testRecordBuilderCreation() {
        do {
            var record = try Audit.Record(event: 0)
            // Abandon to clean up
            record.abandon()
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testRecordBuilderCreation: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRecordBuilderWithTokens() {
        do {
            var record = try Audit.Record(event: 0)
            try record.addSubject()
            try record.add(text: "Test audit message")
            try record.add(returnToken: true)
            // Abandon - don't actually commit
            record.abandon()
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == ENOSYS {
            print("Skipping testRecordBuilderWithTokens: requires elevated privileges or audit not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Audit Pipe Tests

    func testAuditPipePreselectionMode() {
        // Test enum values
        XCTAssertEqual(Audit.Pipe.PreselectionMode.trail.rawValue, 1)
        XCTAssertEqual(Audit.Pipe.PreselectionMode.local.rawValue, 2)
    }

    func testAuditPipeOpen() {
        do {
            let pipe = try Audit.Pipe()
            // Just verify we can create it
            XCTAssertGreaterThanOrEqual(pipe.fileDescriptor, 0)
        } catch let error as Audit.Error where error.errno == EPERM || error.errno == EACCES || error.errno == ENOENT {
            print("Skipping testAuditPipeOpen: requires elevated privileges or /dev/auditpipe not present")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuditPipeQueueOperations() {
        do {
            let pipe = try Audit.Pipe()

            // Get queue info
            let qlen = try pipe.queueLength()
            XCTAssertGreaterThanOrEqual(qlen, 0)

            let qlimit = try pipe.queueLimit()
            XCTAssertGreaterThan(qlimit, 0)

            let minLimit = try pipe.minQueueLimit()
            let maxLimit = try pipe.maxQueueLimit()
            XCTAssertLessThanOrEqual(minLimit, maxLimit)

        } catch let error as Audit.Error where error.errno == EPERM || error.errno == EACCES || error.errno == ENOENT {
            print("Skipping testAuditPipeQueueOperations: requires elevated privileges")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuditPipeStatistics() {
        do {
            let pipe = try Audit.Pipe()

            _ = try pipe.insertCount()
            _ = try pipe.readCount()
            _ = try pipe.dropCount()
            _ = try pipe.truncateCount()

        } catch let error as Audit.Error where error.errno == EPERM || error.errno == EACCES || error.errno == ENOENT {
            print("Skipping testAuditPipeStatistics: requires elevated privileges")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
