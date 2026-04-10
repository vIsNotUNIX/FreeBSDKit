/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class KcmpTests: XCTestCase {

    func testFileDuplicatedDescriptorsAreEqual() throws {
        let path = "/tmp/freebsdkit-kcmp-\(getpid())-\(arc4random()).bin"
        let fd = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        Glibc.unlink(path)
        defer { Glibc.close(fd) }

        let dup = Glibc.dup(fd)
        XCTAssertGreaterThanOrEqual(dup, 0)
        defer { Glibc.close(dup) }

        // dup(2) yields a second descriptor that points at the same file
        // description, so KCMP_FILE must report .equal.
        let me = getpid()
        let result = try kcmp(pid1: me, pid2: me, type: .file, idx1: UInt(fd), idx2: UInt(dup))
        XCTAssertEqual(result, .equal)
    }

    func testFileIndependentOpensAreNotEqual() throws {
        let path = "/tmp/freebsdkit-kcmp-fobj-\(getpid())-\(arc4random()).bin"
        let fd1 = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC, 0o600)
        XCTAssertGreaterThanOrEqual(fd1, 0)
        defer { Glibc.close(fd1) }

        let fd2 = Glibc.open(path, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd2, 0)
        Glibc.unlink(path)
        defer { Glibc.close(fd2) }

        let me = getpid()

        // Two independent opens of the same file get distinct file
        // descriptions, so KCMP_FILE must NOT report .equal.
        let shallow = try kcmp(pid1: me, pid2: me, type: .file, idx1: UInt(fd1), idx2: UInt(fd2))
        XCTAssertNotEqual(shallow, .equal)

        // KCMP_FILEOBJ does a deep comparison and should see the same
        // backing vnode, so it must report .equal.
        let deep = try kcmp(pid1: me, pid2: me, type: .fileObject, idx1: UInt(fd1), idx2: UInt(fd2))
        XCTAssertEqual(deep, .equal)
    }

    func testFilesTableIsSharedWithSelf() throws {
        // A process trivially shares its own fd table, signal handler
        // table, and address space with itself.
        let me = getpid()
        XCTAssertEqual(try kcmp(pid1: me, pid2: me, type: .files), .equal)
        XCTAssertEqual(try kcmp(pid1: me, pid2: me, type: .sighand), .equal)
        XCTAssertEqual(try kcmp(pid1: me, pid2: me, type: .vm), .equal)
    }

    func testInvalidPidThrows() {
        // PID 0x7fffffff is essentially guaranteed not to exist.
        XCTAssertThrowsError(
            try kcmp(pid1: pid_t(0x7fffffff), pid2: getpid(), type: .vm)
        ) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            // Either the process doesn't exist (ESRCH) or we lack
            // permission to debug it (EPERM); both are reasonable.
            XCTAssertTrue(
                posix.code == .ESRCH || posix.code == .EPERM,
                "unexpected error code \(posix.code)"
            )
        }
    }
}
