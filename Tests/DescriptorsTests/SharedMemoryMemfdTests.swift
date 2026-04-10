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

final class SharedMemoryMemfdTests: XCTestCase {

    func testMemfdRoundTrip() throws {
        let desc: TestSharedMemoryDescriptor = try .memfd(name: "freebsdkit-memfd-test")
        defer { desc.close() }

        // Size to one page-ish, then write a marker via mmap and read it
        // back through pread to make sure it's the same kernel object.
        let size = 64
        try desc.setSize(size)

        let region = try desc.map(
            size: size,
            protection: [.read, .write],
            flags: .shared
        )
        let bytes = UnsafeMutableRawPointer(mutating: region.base)
            .assumingMemoryBound(to: UInt8.self)
        for i in 0..<size {
            bytes[i] = UInt8(i & 0xff)
        }
        try region.unmap()

        var buf = [UInt8](repeating: 0, count: size)
        let n = desc.unsafe { fd -> Int in
            buf.withUnsafeMutableBytes { dst in
                Glibc.pread(fd, dst.baseAddress, dst.count, 0)
            }
        }
        XCTAssertEqual(n, size)
        for i in 0..<size {
            XCTAssertEqual(buf[i], UInt8(i & 0xff))
        }
    }

    func testMemfdAllowSealingPermitsSeals() throws {
        let desc: TestSharedMemoryDescriptor = try .memfd(
            name: "freebsdkit-memfd-seal",
            flags: [.closeOnExec, .allowSealing]
        )
        defer { desc.close() }
        try desc.setSize(4096)

        // F_ADD_SEALS / F_SEAL_WRITE come from <sys/fcntl.h>. With
        // .allowSealing the kernel must accept the request.
        let r = desc.unsafe { fd in
            Glibc.fcntl(fd, F_ADD_SEALS, F_SEAL_WRITE)
        }
        XCTAssertEqual(r, 0, "expected F_ADD_SEALS to succeed (errno=\(errno))")
    }

    func testMemfdWithoutSealingRejectsSeals() throws {
        let desc: TestSharedMemoryDescriptor = try .memfd(
            name: "freebsdkit-memfd-noseal"
        )
        defer { desc.close() }
        try desc.setSize(4096)

        let r = desc.unsafe { fd in
            Glibc.fcntl(fd, F_ADD_SEALS, F_SEAL_WRITE)
        }
        XCTAssertEqual(r, -1)
        XCTAssertEqual(errno, EPERM)
    }
}
