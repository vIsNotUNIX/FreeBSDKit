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

final class FspacectlTests: XCTestCase {

    private func makeTempFile(contents: Data, name: String) throws -> (path: String, fd: Int32) {
        let path = "/tmp/freebsdkit-\(name)-\(getpid())-\(arc4random()).bin"
        let fd = Glibc.open(path, O_CREAT | O_RDWR | O_TRUNC, 0o600)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        let written = contents.withUnsafeBytes { buf -> Int in
            Glibc.pwrite(fd, buf.baseAddress, buf.count, 0)
        }
        guard written == contents.count else {
            Glibc.close(fd)
            Glibc.unlink(path)
            throw POSIXError(.EIO)
        }
        return (path, fd)
    }

    private func readAll(fd: Int32) -> Data {
        var st = Glibc.stat()
        guard Glibc.fstat(fd, &st) == 0, st.st_size > 0 else { return Data() }
        var buf = Data(count: Int(st.st_size))
        let n = buf.withUnsafeMutableBytes { ptr -> Int in
            Glibc.pread(fd, ptr.baseAddress, ptr.count, 0)
        }
        return buf.prefix(max(0, n))
    }

    func testFspacectlPunchesHole() throws {
        // 4 KiB of 0xAB. Punch a 1 KiB hole in the middle.
        let payload = Data(repeating: 0xAB, count: 4096)
        let (path, fd) = try makeTempFile(contents: payload, name: "fspc")
        defer {
            Glibc.close(fd)
            Glibc.unlink(path)
        }

        let result = try fspacectl(
            fd: fd,
            command: .deallocate,
            offset: 1024,
            length: 1024
        )
        // After a successful full deallocation, the kernel reports
        // r_len == 0 and r_offset bumped to the end of the request.
        XCTAssertEqual(result.remainingLength, 0)
        XCTAssertEqual(result.nextOffset, 2048)

        // File size must be unchanged.
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_size, off_t(payload.count))

        // Read the whole file back. The middle 1 KiB must read as zero;
        // the surrounding bytes must still be 0xAB.
        let after = readAll(fd: fd)
        XCTAssertEqual(after.count, payload.count)
        XCTAssertEqual(after.prefix(1024), Data(repeating: 0xAB, count: 1024))
        XCTAssertEqual(after.subdata(in: 1024..<2048), Data(repeating: 0x00, count: 1024))
        XCTAssertEqual(after.suffix(from: 2048), Data(repeating: 0xAB, count: 2048))
    }
}
