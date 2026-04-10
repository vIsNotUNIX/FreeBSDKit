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

final class FunlinkatTests: XCTestCase {

    func testFunlinkatRemovesMatchingFile() throws {
        let dirPath = "/tmp/freebsdkit-funlink-\(getpid())"
        XCTAssertEqual(Glibc.mkdir(dirPath, 0o700), 0)
        defer { _ = Glibc.rmdir(dirPath) }

        let dirFD = Glibc.open(dirPath, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(dirFD, 0)
        defer { Glibc.close(dirFD) }

        let name = "victim"
        let fileFD = Glibc.openat(dirFD, name, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(fileFD, 0)
        defer { Glibc.close(fileFD) }

        // Sanity: entry currently exists.
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstatat(dirFD, name, &st, 0), 0)

        // Remove via funlinkat — passing the matching fd.
        try funlinkat(dfd: dirFD, path: name, fd: fileFD)

        // Entry must now be gone.
        XCTAssertEqual(Glibc.fstatat(dirFD, name, &st, 0), -1)
        XCTAssertEqual(errno, ENOENT)
    }

    func testFunlinkatRefusesStaleFile() throws {
        let dirPath = "/tmp/freebsdkit-funlink-stale-\(getpid())"
        XCTAssertEqual(Glibc.mkdir(dirPath, 0o700), 0)
        defer { _ = Glibc.rmdir(dirPath) }

        let dirFD = Glibc.open(dirPath, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(dirFD, 0)
        defer { Glibc.close(dirFD) }

        let name = "entry"

        // Create the original file and hold an fd to it.
        let originalFD = Glibc.openat(dirFD, name, O_CREAT | O_RDWR | O_EXCL, 0o600)
        XCTAssertGreaterThanOrEqual(originalFD, 0)
        defer { Glibc.close(originalFD) }

        // Replace the directory entry with a different file (different inode).
        XCTAssertEqual(Glibc.unlinkat(dirFD, name, 0), 0)
        let replacementFD = Glibc.openat(dirFD, name, O_CREAT | O_RDWR | O_EXCL, 0o600)
        XCTAssertGreaterThanOrEqual(replacementFD, 0)
        defer { Glibc.close(replacementFD) }

        // funlinkat with originalFD must refuse — the entry no longer
        // resolves to that file.
        XCTAssertThrowsError(
            try funlinkat(dfd: dirFD, path: name, fd: originalFD)
        ) { error in
            // FreeBSD documents this as EDEADLK.
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .EDEADLK)
        }

        // The replacement must still be there.
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstatat(dirFD, name, &st, 0), 0)

        // Clean up.
        XCTAssertEqual(Glibc.unlinkat(dirFD, name, 0), 0)
    }
}
