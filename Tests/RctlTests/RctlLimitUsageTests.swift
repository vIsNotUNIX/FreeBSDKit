/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import FreeBSDKit
@testable import Rctl

final class RctlLimitUsageTests: XCTestCase {

    func testLimitUsageReportsOpenFiles() throws {
        // Open a few extra fds and verify nofile usage rises by at least
        // that many. We can't assert exact equality because the test
        // harness has its own descriptors in flight.
        let baseline = try Rctl.limitUsage(of: .nofile)

        var extras: [Int32] = []
        defer { for fd in extras { Glibc.close(fd) } }

        for _ in 0..<8 {
            let fd = Glibc.open("/dev/null", O_RDONLY | O_CLOEXEC)
            XCTAssertGreaterThanOrEqual(fd, 0)
            extras.append(fd)
        }

        let after = try Rctl.limitUsage(of: .nofile)
        XCTAssertGreaterThanOrEqual(after, baseline + rlim_t(extras.count))
    }

    func testLimitUsageDataIsNonZero() throws {
        // Every running process has some data segment.
        let usage = try Rctl.limitUsage(of: .data)
        XCTAssertGreaterThan(usage, 0)
    }

    func testLimitUsageUnaccountedResourceThrowsENXIO() {
        // RLIMIT_FSIZE and RLIMIT_CORE are enforced but not accounted;
        // the kernel returns ENXIO for them.
        XCTAssertThrowsError(try Rctl.limitUsage(of: .fsize)) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .ENXIO)
        }
    }
}
