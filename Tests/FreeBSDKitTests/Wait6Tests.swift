/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class Wait6Tests: XCTestCase {

    func testWait6OnExitedChild() throws {
        let pid = fork()
        if pid == 0 {
            _exit(7)
        }
        XCTAssertGreaterThan(pid, 0, "fork failed")

        let result = try wait6(idType: .pid, id: id_t(pid), options: [.exited])
        let r = try XCTUnwrap(result)
        XCTAssertEqual(r.pid, pid)

        // WIFEXITED + exit code 7.
        XCTAssertEqual(r.status & 0x7f, 0)
        XCTAssertEqual((r.status >> 8) & 0xff, 7)

        // siginfo records that the child exited with code 7.
        XCTAssertEqual(r.signalInfo.si_signo, SIGCHLD)
        XCTAssertEqual(r.signalInfo.si_status, 7)
    }

    func testWait6NoHangReturnsNilWhenNoChildExited() throws {
        // Spawn a child that lives long enough that we observe a non-event
        // before it exits.
        let pid = fork()
        if pid == 0 {
            // Sleep ~500 ms then exit. The parent will reap with a
            // blocking wait6 after the noHang test.
            var ts = timespec(tv_sec: 0, tv_nsec: 500_000_000)
            nanosleep(&ts, nil)
            _exit(0)
        }
        XCTAssertGreaterThan(pid, 0)

        // Immediate non-blocking poll: child is still running, expect nil.
        let pollResult = try wait6(
            idType: .pid,
            id: id_t(pid),
            options: [.exited, .noHang]
        )
        XCTAssertNil(pollResult)

        // Reap it for real so we don't leak a zombie.
        let blockingResult = try wait6(
            idType: .pid,
            id: id_t(pid),
            options: [.exited]
        )
        XCTAssertNotNil(blockingResult)
        XCTAssertEqual(blockingResult?.pid, pid)
    }

    func testWait6CapturesChildRusage() throws {
        let pid = fork()
        if pid == 0 {
            // Burn a tiny bit of CPU so the rusage fields are non-zero.
            var sum: UInt64 = 0
            for i in 0..<200_000 {
                sum &+= UInt64(i)
            }
            // Force the optimizer to keep the loop.
            if sum == .max { _exit(123) }
            _exit(0)
        }
        XCTAssertGreaterThan(pid, 0)

        let result = try XCTUnwrap(
            try wait6(idType: .pid, id: id_t(pid), options: [.exited])
        )
        XCTAssertEqual(result.pid, pid)

        // The waited-for child should report some user-space CPU time.
        // We can't predict exact values, just sanity-check the fields are
        // present and non-negative.
        XCTAssertGreaterThanOrEqual(result.selfRusage.ru_utime.tv_sec, 0)
        XCTAssertGreaterThanOrEqual(result.selfRusage.ru_stime.tv_sec, 0)
        // Children-of-children rusage should be all-zero (the test child
        // had no descendants).
        XCTAssertEqual(result.childrenRusage.ru_utime.tv_sec, 0)
        XCTAssertEqual(result.childrenRusage.ru_utime.tv_usec, 0)
    }

    func testWait6OnNoChildThrowsECHILD() {
        // No children to wait for at this idType+id; the kernel returns
        // ECHILD.
        XCTAssertThrowsError(
            try wait6(idType: .pid, id: id_t(0x7fffffff), options: [.exited])
        ) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .ECHILD)
        }
    }
}
