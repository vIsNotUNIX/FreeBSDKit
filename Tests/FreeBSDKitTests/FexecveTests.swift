/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class FexecveTests: XCTestCase {

    func testFexecveTrueRunsToCompletion() throws {
        // Open /usr/bin/true (or /bin/true) for execution.
        let candidates = ["/usr/bin/true", "/bin/true"]
        var binaryFD: Int32 = -1
        var binaryPath: String = ""
        for path in candidates {
            let fd = Glibc.open(path, O_RDONLY | O_CLOEXEC)
            if fd >= 0 {
                binaryFD = fd
                binaryPath = path
                break
            }
        }
        guard binaryFD >= 0 else {
            throw XCTSkip("no /bin/true or /usr/bin/true on this host")
        }
        defer { Glibc.close(binaryFD) }

        let pid = fork()
        if pid == 0 {
            // Child: fexecve. On success this does not return; on failure
            // we exit with a sentinel so the parent sees it.
            do {
                try fexecve(fd: binaryFD, argv: [binaryPath])
            } catch {
                _exit(127)
            }
            _exit(126) // unreachable
        }

        XCTAssertGreaterThan(pid, 0, "fork failed: errno=\(errno)")

        var status: Int32 = 0
        let r = waitpid(pid, &status, 0)
        XCTAssertEqual(r, pid)

        // Expect a normal exit with status 0 — fexecve transferred control
        // into /bin/true and the new program ran to completion.
        // WIFEXITED: low 7 bits of status are zero.
        XCTAssertEqual(status & 0x7f, 0,
            "child must have terminated normally, status=\(status)")
        XCTAssertEqual((status >> 8) & 0xff, 0,
            "expected exit code 0, status=\(status)")
    }

    func testFexecveOnNonExecutableFails() throws {
        // /etc/hosts is a regular file but not executable, so fexecve
        // should fail with EACCES (or ENOEXEC).
        let fd = Glibc.open("/etc/hosts", O_RDONLY | O_CLOEXEC)
        guard fd >= 0 else {
            throw XCTSkip("no /etc/hosts to use as a non-executable target")
        }
        defer { Glibc.close(fd) }

        // Run in a child so an unlikely success doesn't replace the test
        // process.
        let pid = fork()
        if pid == 0 {
            do {
                try fexecve(fd: fd, argv: ["/etc/hosts"])
            } catch {
                _exit(42) // expected path
            }
            _exit(0) // would mean fexecve unexpectedly succeeded
        }
        XCTAssertGreaterThan(pid, 0)

        var status: Int32 = 0
        _ = waitpid(pid, &status, 0)
        XCTAssertEqual((status >> 8) & 0xff, 42,
            "child should have caught the fexecve error, status=\(status)")
    }
}
