/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import CAudit

final class CAuditTests: XCTestCase {

    // MARK: - Constants Tests

    func testAuditConditionConstants() {
        // Verify constants are properly defined
        XCTAssertEqual(CAUDIT_AUC_UNSET, 0)
        XCTAssertEqual(CAUDIT_AUC_AUDITING, 1)
        XCTAssertEqual(CAUDIT_AUC_NOAUDIT, 2)
        XCTAssertEqual(CAUDIT_AUC_DISABLED, -1)
    }

    func testAuditPolicyConstants() {
        // Verify policy flags are non-zero (actual values may vary)
        XCTAssertNotEqual(CAUDIT_POLICY_CNT, 0)
        XCTAssertNotEqual(CAUDIT_POLICY_AHLT, 0)
        XCTAssertNotEqual(CAUDIT_POLICY_ARGV, 0)
        XCTAssertNotEqual(CAUDIT_POLICY_ARGE, 0)
    }

    func testTokenTypeConstants() {
        // Verify token type identifiers are defined
        XCTAssertNotEqual(CAUDIT_AUT_HEADER32, 0)
        XCTAssertNotEqual(CAUDIT_AUT_TRAILER, 0)
        XCTAssertNotEqual(CAUDIT_AUT_SUBJECT32, 0)
        XCTAssertNotEqual(CAUDIT_AUT_RETURN32, 0)
        XCTAssertNotEqual(CAUDIT_AUT_TEXT, 0)
        XCTAssertNotEqual(CAUDIT_AUT_PATH, 0)
    }

    func testDefaultAuditID() {
        // CAUDIT_DEFAUDITID should be (uid_t)(-1) which is max uint32
        XCTAssertEqual(CAUDIT_DEFAUDITID, UInt32.max)
    }

    // MARK: - Ioctl Command Tests

    func testIoctlCommandsAreDefined() {
        // Verify ioctl wrapper functions return non-zero values
        XCTAssertNotEqual(caudit_pipe_get_qlen_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_qlimit_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_set_qlimit_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_qlimit_min_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_qlimit_max_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_preselect_flags_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_set_preselect_flags_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_preselect_mode_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_set_preselect_mode_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_flush_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_maxauditdata_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_inserts_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_reads_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_drops_cmd(), 0)
        XCTAssertNotEqual(caudit_pipe_get_truncates_cmd(), 0)
    }

    func testIoctlCommandsAreDistinct() {
        // Verify each ioctl command has a unique value
        let commands: [UInt] = [
            caudit_pipe_get_qlen_cmd(),
            caudit_pipe_get_qlimit_cmd(),
            caudit_pipe_set_qlimit_cmd(),
            caudit_pipe_get_qlimit_min_cmd(),
            caudit_pipe_get_qlimit_max_cmd(),
            caudit_pipe_get_preselect_flags_cmd(),
            caudit_pipe_set_preselect_flags_cmd(),
            caudit_pipe_get_preselect_mode_cmd(),
            caudit_pipe_set_preselect_mode_cmd(),
            caudit_pipe_flush_cmd(),
            caudit_pipe_get_maxauditdata_cmd(),
            caudit_pipe_get_inserts_cmd(),
            caudit_pipe_get_reads_cmd(),
            caudit_pipe_get_drops_cmd(),
            caudit_pipe_get_truncates_cmd(),
        ]

        let uniqueCommands = Set(commands)
        XCTAssertEqual(commands.count, uniqueCommands.count, "Ioctl commands should all be unique")
    }

    // MARK: - State Query Tests

    func testGetStateReturnsValidValue() {
        // caudit_get_state should return a valid audit condition
        let state = caudit_get_state()
        let validStates: Set<Int32> = [
            CAUDIT_AUC_UNSET,
            CAUDIT_AUC_AUDITING,
            CAUDIT_AUC_NOAUDIT,
            CAUDIT_AUC_DISABLED
        ]
        XCTAssertTrue(validStates.contains(state), "State \(state) should be a valid audit condition")
    }

    // MARK: - Token Creation Tests

    func testCreateTextToken() {
        let token = caudit_to_text("test message")
        XCTAssertNotNil(token, "Should create text token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreatePathToken() {
        let token = caudit_to_path("/tmp/test")
        XCTAssertNotNil(token, "Should create path token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateReturn32Token() {
        let token = caudit_to_return32(0, 0)
        XCTAssertNotNil(token, "Should create return32 token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateReturn64Token() {
        let token = caudit_to_return64(0, 0)
        XCTAssertNotNil(token, "Should create return64 token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateArg32Token() {
        let token = caudit_to_arg32(1, "arg1", 42)
        XCTAssertNotNil(token, "Should create arg32 token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateArg64Token() {
        let token = caudit_to_arg64(1, "arg1", 42)
        XCTAssertNotNil(token, "Should create arg64 token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateExitToken() {
        let token = caudit_to_exit(0, 0)
        XCTAssertNotNil(token, "Should create exit token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    func testCreateOpaqueToken() {
        let data: [CChar] = [0x01, 0x02, 0x03, 0x04]
        let token = data.withUnsafeBufferPointer { ptr in
            caudit_to_opaque(ptr.baseAddress, UInt16(ptr.count))
        }
        XCTAssertNotNil(token, "Should create opaque token")
        if let tok = token {
            caudit_free_token(tok)
        }
    }

    // MARK: - Record Builder Tests

    func testOpenAndAbandonRecord() {
        let descriptor = caudit_open()
        XCTAssertGreaterThanOrEqual(descriptor, 0, "Should open audit record descriptor")

        // Close with AU_TO_NO_WRITE to abandon
        let result = caudit_close(descriptor, CAUDIT_TO_NO_WRITE, 0)
        XCTAssertEqual(result, 0, "Should close/abandon record successfully")
    }

    func testWriteTokenToRecord() {
        let descriptor = caudit_open()
        XCTAssertGreaterThanOrEqual(descriptor, 0)

        // Create and write a text token
        if let token = caudit_to_text("test") {
            let writeResult = caudit_write(descriptor, token)
            XCTAssertEqual(writeResult, 0, "Should write token to record")
            // Note: caudit_write takes ownership of token, don't free it
        }

        // Abandon the record
        caudit_close(descriptor, CAUDIT_TO_NO_WRITE, 0)
    }

    // MARK: - Event/Class Database Tests

    func testEventDatabaseIteration() {
        caudit_setauevent()

        var count = 0
        while let event = caudit_getauevent() {
            XCTAssertNotNil(event.pointee.ae_name)
            XCTAssertNotNil(event.pointee.ae_desc)
            count += 1
            if count > 10 { break } // Just verify iteration works
        }

        caudit_endauevent()
        XCTAssertGreaterThan(count, 0, "Should iterate over events")
    }

    func testClassDatabaseIteration() {
        caudit_setauclass()

        var count = 0
        while let classEnt = caudit_getauclassent() {
            XCTAssertNotNil(classEnt.pointee.ac_name)
            XCTAssertNotNil(classEnt.pointee.ac_desc)
            count += 1
            if count > 10 { break }
        }

        caudit_endauclass()
        XCTAssertGreaterThan(count, 0, "Should iterate over classes")
    }

    func testGetEventByNumber() {
        // AUE_NULL is typically 0
        if let event = caudit_getauevnum(0) {
            XCTAssertNotNil(event.pointee.ae_name)
        }
        // Event number 1 (AUE_EXIT) should exist
        if let event = caudit_getauevnum(1) {
            XCTAssertNotNil(event.pointee.ae_name)
        }
    }

    // MARK: - Preselection Tests

    func testPreselectionCheck() {
        var mask = au_mask_t()
        mask.am_success = ~0  // All classes on success
        mask.am_failure = ~0  // All classes on failure

        // Check if event 1 would be audited with this mask
        // AU_PRS_SUCCESS = 1, AU_PRS_REREAD = 1
        let result = caudit_preselect(1, &mask, 1, 1)
        // Result: -1 on error, 0 if not preselected, 1 if preselected
        XCTAssertTrue(result >= -1 && result <= 1, "Preselect should return -1, 0, or 1, got \(result)")
    }

    // MARK: - Mask Structure Tests

    func testAuMaskStructure() {
        var mask = au_mask_t()
        mask.am_success = 0x1234
        mask.am_failure = 0x5678

        XCTAssertEqual(mask.am_success, 0x1234)
        XCTAssertEqual(mask.am_failure, 0x5678)
    }

    func testAuTidStructure() {
        var tid = au_tid_t()
        tid.port = 1234
        tid.machine = 0x7F000001  // 127.0.0.1

        XCTAssertEqual(tid.port, 1234)
        XCTAssertEqual(tid.machine, 0x7F000001)
    }
}
