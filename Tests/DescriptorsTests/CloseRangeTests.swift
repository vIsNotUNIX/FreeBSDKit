/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
import FreeBSDKit
@testable import Descriptors

final class CloseRangeTests: XCTestCase {

    func testCloseRangeClosesDescriptors() throws {
        // Open a few temp files to get a known set of fds.
        var fds: [Int32] = []
        for i in 0..<3 {
            let path = "/tmp/freebsdkit-cr-\(getpid())-\(i).bin"
            let fd = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC, 0o600)
            XCTAssertGreaterThanOrEqual(fd, 0)
            Glibc.unlink(path) // unlink immediately; fd keeps it alive
            fds.append(fd)
        }

        let low = UInt32(fds.min()!)
        let high = UInt32(fds.max()!)

        try closeRange(low: low, high: high)

        // After close_range every fd in the range must be closed.
        for fd in fds {
            // fcntl(F_GETFD) on a closed fd returns -1/EBADF.
            let r = Glibc.fcntl(fd, F_GETFD)
            XCTAssertEqual(r, -1, "fd \(fd) should be closed")
            XCTAssertEqual(errno, EBADF)
        }
    }

    func testCloseRangeCloexecMarksDescriptors() throws {
        let path = "/tmp/freebsdkit-cr-cloexec-\(getpid()).bin"
        let fd = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        Glibc.unlink(path)
        defer { Glibc.close(fd) }

        // Clear FD_CLOEXEC explicitly so we know the flag transition is
        // caused by close_range.
        XCTAssertEqual(Glibc.fcntl(fd, F_SETFD, 0), 0)
        XCTAssertEqual(Glibc.fcntl(fd, F_GETFD) & FD_CLOEXEC, 0)

        try closeRange(low: UInt32(fd), high: UInt32(fd), flags: .cloexec)

        // fd is still open, but FD_CLOEXEC must now be set.
        let after = Glibc.fcntl(fd, F_GETFD)
        XCTAssertGreaterThanOrEqual(after, 0)
        XCTAssertNotEqual(after & FD_CLOEXEC, 0)
    }
}
