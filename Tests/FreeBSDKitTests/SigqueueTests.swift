/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class SigqueueTests: XCTestCase {

    func testSigqueueDeliversPayloadToSelf() throws {
        // Use a real-time signal so the payload is preserved even if the
        // process is busy at delivery time.
        let signo = SIGRTMIN

        // Block the signal so we can receive it deterministically via
        // sigtimedwait instead of an async handler.
        var mask = sigset_t()
        sigemptyset(&mask)
        sigaddset(&mask, signo)
        var oldMask = sigset_t()
        XCTAssertEqual(sigprocmask(SIG_BLOCK, &mask, &oldMask), 0)
        defer { _ = sigprocmask(SIG_SETMASK, &oldMask, nil) }

        // Queue the signal with a payload.
        let payload: Int32 = 0x4243
        try queueSignal(pid: getpid(), signal: signo, value: payload)

        // Receive it.
        var info = siginfo_t()
        var timeout = timespec(tv_sec: 1, tv_nsec: 0)
        let received = sigtimedwait(&mask, &info, &timeout)
        XCTAssertEqual(received, signo, "sigtimedwait did not return our signal")

        XCTAssertEqual(info.si_signo, signo)
        XCTAssertEqual(info.si_code, SI_QUEUE)
        XCTAssertEqual(info.si_value.sival_int, payload)
    }

    func testSigqueueToInvalidPidThrows() {
        XCTAssertThrowsError(
            try queueSignal(pid: pid_t(0x7fffffff), signal: SIGUSR1)
        ) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            // Either no such process or no permission.
            XCTAssertTrue(
                posix.code == .ESRCH || posix.code == .EPERM,
                "unexpected code \(posix.code)"
            )
        }
    }
}
