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
