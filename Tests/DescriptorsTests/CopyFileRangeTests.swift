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

final class CopyFileRangeTests: XCTestCase {

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

    func testCopyFileRangeFull() throws {
        let payload = Data((0..<2048).map { UInt8($0 & 0xff) })
        let (srcPath, srcFD) = try makeTempFile(contents: payload, name: "cfr-src")
        let (dstPath, dstFD) = try makeTempFile(contents: Data(), name: "cfr-dst")
        defer {
            Glibc.close(srcFD); Glibc.unlink(srcPath)
            Glibc.close(dstFD); Glibc.unlink(dstPath)
        }

        var inOff: off_t? = 0
        var outOff: off_t? = 0
        let copied = try copyFileRange(
            from: srcFD,
            inOffset: &inOff,
            to: dstFD,
            outOffset: &outOff,
            length: payload.count
        )

        XCTAssertEqual(copied, payload.count)
        XCTAssertEqual(inOff, off_t(payload.count))
        XCTAssertEqual(outOff, off_t(payload.count))

        XCTAssertEqual(readAll(fd: dstFD), payload)
    }

    func testCopyFileRangeWithOffsets() throws {
        let payload = Data((0..<512).map { UInt8($0 & 0xff) })
        let (srcPath, srcFD) = try makeTempFile(contents: payload, name: "cfr-off-src")
        // Pre-fill destination with 256 bytes of 0xFF so we can see exactly
        // what copy_file_range overwrites.
        let prefill = Data(repeating: 0xFF, count: 256)
        let (dstPath, dstFD) = try makeTempFile(contents: prefill, name: "cfr-off-dst")
        defer {
            Glibc.close(srcFD); Glibc.unlink(srcPath)
            Glibc.close(dstFD); Glibc.unlink(dstPath)
        }

        // Copy bytes [100, 200) from src into dst at offset 50.
        var inOff: off_t? = 100
        var outOff: off_t? = 50
        let copied = try copyFileRange(
            from: srcFD,
            inOffset: &inOff,
            to: dstFD,
            outOffset: &outOff,
            length: 100
        )
        XCTAssertEqual(copied, 100)

        let result = readAll(fd: dstFD)
        XCTAssertEqual(result.count, 256)
        // [0..50)   -> still 0xFF
        // [50..150) -> payload[100..200)
        // [150..256) -> still 0xFF
        XCTAssertEqual(result.prefix(50), Data(repeating: 0xFF, count: 50))
        XCTAssertEqual(result.subdata(in: 50..<150), payload.subdata(in: 100..<200))
        XCTAssertEqual(result.suffix(from: 150), Data(repeating: 0xFF, count: 106))
    }
}
