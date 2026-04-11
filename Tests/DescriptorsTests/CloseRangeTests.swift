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
        // Use pipe(2) to get a pair of file descriptors that the kernel
        // is guaranteed to allocate contiguously: it calls falloc twice
        // inside one syscall under the per-process descriptor lock, so
        // no other thread can slip a fd in between. This sidesteps the
        // XCTest-runner contention that broke an earlier "open three
        // temp files and hope" approach.
        var pipefds: [Int32] = [-1, -1]
        let pipeResult = pipefds.withUnsafeMutableBufferPointer { buf in
            Glibc.pipe(buf.baseAddress)
        }
        XCTAssertEqual(pipeResult, 0, "pipe(2) failed: errno=\(errno)")

        // Defensive: belt-and-braces close in case the assertions below
        // fail before close_range runs.
        var owned = true
        defer {
            if owned {
                for fd in pipefds where fd >= 0 { Glibc.close(fd) }
            }
        }

        XCTAssertGreaterThanOrEqual(pipefds[0], 0)
        XCTAssertGreaterThanOrEqual(pipefds[1], 0)
        XCTAssertEqual(pipefds[1], pipefds[0] + 1,
                       "pipe(2) should hand out contiguous fds")

        try closeRange(low: UInt32(pipefds[0]), high: UInt32(pipefds[1]))

        // Both fds in the range must now report EBADF.
        for fd in pipefds {
            let r = Glibc.fcntl(fd, F_GETFD)
            XCTAssertEqual(r, -1, "fd \(fd) should be closed")
            XCTAssertEqual(errno, EBADF)
        }

        owned = false
    }

    func testCloseRangeCloexecMarksDescriptors() throws {
        let path = "/tmp/freebsdkit-cr-cloexec-\(getpid())-\(arc4random()).bin"
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
