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
        // Open three temp files. To avoid stomping any descriptor that
        // another XCTest thread happens to allocate concurrently, we
        // verify the three fds we got back are contiguous before
        // calling close_range — if they aren't, another thread raced
        // with us and we re-open until they are.
        var fds: [Int32] = []
        var attempts = 0
        defer {
            // Best-effort cleanup if the assertion below fails before
            // close_range runs.
            for fd in fds { Glibc.close(fd) }
        }

        while attempts < 16 {
            attempts += 1
            for fd in fds { Glibc.close(fd) }
            fds.removeAll(keepingCapacity: true)

            for i in 0..<3 {
                let path = "/tmp/freebsdkit-cr-\(getpid())-\(arc4random())-\(i).bin"
                let fd = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC | O_CLOEXEC, 0o600)
                XCTAssertGreaterThanOrEqual(fd, 0)
                Glibc.unlink(path) // unlink immediately; fd keeps it alive
                fds.append(fd)
            }

            // Confirm the fds are contiguous. If something allocated a fd
            // in the gap, retry.
            if fds[1] == fds[0] + 1 && fds[2] == fds[0] + 2 {
                break
            }
        }
        XCTAssertEqual(fds[1], fds[0] + 1, "could not allocate contiguous fds")
        XCTAssertEqual(fds[2], fds[0] + 2)

        let low = UInt32(fds[0])
        let high = UInt32(fds[2])

        try closeRange(low: low, high: high)

        // After close_range every fd in the range must be closed.
        for fd in fds {
            // fcntl(F_GETFD) on a closed fd returns -1/EBADF.
            let r = Glibc.fcntl(fd, F_GETFD)
            XCTAssertEqual(r, -1, "fd \(fd) should be closed")
            XCTAssertEqual(errno, EBADF)
        }

        // Tell the defer not to double-close.
        fds.removeAll()
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
