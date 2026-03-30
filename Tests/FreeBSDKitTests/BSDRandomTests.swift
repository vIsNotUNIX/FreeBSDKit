/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit

final class BSDRandomTests: XCTestCase {

    func testBytesGeneration() throws {
        let bytes = try BSDRandom.bytes(32)
        XCTAssertEqual(bytes.count, 32)
        // Verify not all zeros (statistically impossible for 32 random bytes)
        XCTAssertFalse(bytes.allSatisfy { $0 == 0 })
    }

    func testFillBuffer() throws {
        var buffer = [UInt8](repeating: 0, count: 16)
        try BSDRandom.fill(&buffer)
        XCTAssertFalse(buffer.allSatisfy { $0 == 0 })
    }

    func testValueGeneration() throws {
        let value1: UInt64 = try BSDRandom.value()
        let value2: UInt64 = try BSDRandom.value()
        // Two random UInt64s should not be equal (statistically)
        XCTAssertNotEqual(value1, value2)
    }

    func testLargeBuffer() throws {
        // Test that large buffers work (may require multiple syscalls)
        let bytes = try BSDRandom.bytes(1024 * 1024)  // 1 MB
        XCTAssertEqual(bytes.count, 1024 * 1024)
    }

    func testNonBlockingMaySucceed() throws {
        // Non-blocking should generally succeed on a running system
        do {
            let bytes = try BSDRandom.bytes(16, flags: .nonBlocking)
            XCTAssertEqual(bytes.count, 16)
        } catch BSDRandom.Error.wouldBlock {
            // This is acceptable if entropy pool is exhausted
        }
    }
}
