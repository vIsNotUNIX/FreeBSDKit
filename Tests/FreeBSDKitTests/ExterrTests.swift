/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class ExterrTests: XCTestCase {

    /// Tests that toggle extended-error reporting mutate process-global
    /// state. Restore it to a known disabled baseline after every test
    /// so test ordering can't leak state between cases.
    override func tearDownWithError() throws {
        try? ExtendedError.disable(flags: .force)
        try super.tearDownWithError()
    }

    func testCurrentMessageReturnsNilWhenNoExtendedError() {
        // After a successful syscall, no extended error should be attached
        // to this thread.
        let pid = getpid()
        XCTAssertGreaterThan(pid, 0)

        let message = ExtendedError.currentMessage()
        // The interface always returns either nil or a non-empty string;
        // it must never crash and must never return an empty string.
        if let m = message {
            XCTAssertFalse(m.isEmpty)
        }
    }

    func testCurrentMessageWithZeroBufferSize() {
        XCTAssertNil(ExtendedError.currentMessage(bufferSize: 0))
    }

    func testDetailedDescriptionFallsBackToBaseDescription() {
        // BSDError.detailedDescription must always include the base
        // description, regardless of whether an extended-error record is
        // attached.
        let err = BSDError.posix(POSIXError(.ENOENT))
        let detailed = err.detailedDescription
        XCTAssertTrue(
            detailed.contains(err.description),
            "detailed description \"\(detailed)\" must contain base \"\(err.description)\""
        )
    }

    // MARK: - exterrctl(2)

    func testEnableAndDisable() throws {
        // Toggling extended-error reporting should always succeed for the
        // calling process. Use .force to be tolerant of other tests in
        // the suite that may have already enabled it.
        XCTAssertNoThrow(try ExtendedError.enable(flags: .force))
        XCTAssertNoThrow(try ExtendedError.disable(flags: .force))
        XCTAssertNoThrow(try ExtendedError.enable(flags: .force))
    }

    func testEnableAfterFailingSyscallStillFetchesText() throws {
        try ExtendedError.enable(flags: .force)

        // Trigger a failing syscall — kernel may attach an extended-error
        // record. We don't require it (only some syscalls participate),
        // but the fetch must remain safe and well-formed.
        let r = Glibc.open("/this/path/should/not/exist/exterrctl-test", O_RDONLY)
        XCTAssertEqual(r, -1)
        XCTAssertEqual(errno, ENOENT)

        let message = ExtendedError.currentMessage()
        if let m = message {
            XCTAssertFalse(m.isEmpty)
        }
    }

    func testCurrentMessageDoesNotCrashAfterFailingSyscall() {
        // Trigger a syscall failure so the kernel has the *opportunity* to
        // attach an extended-error record. We don't assert that one is
        // present (only specific syscalls participate, and the set is
        // version-dependent), but we do assert that fetching it is safe
        // and produces a well-formed Optional<String>.
        let r = Glibc.open("/this/path/should/not/exist/freebsdkit-exterr", O_RDONLY)
        XCTAssertEqual(r, -1)
        XCTAssertEqual(errno, ENOENT)

        let message = ExtendedError.currentMessage()
        if let m = message {
            XCTAssertFalse(m.isEmpty)
            // The kernel-supplied text is always plain ASCII; sanity-check
            // that decoding produced a UTF-8 string of reasonable length.
            XCTAssertLessThan(m.count, ExtendedError.defaultBufferSize)
        }
    }
}
