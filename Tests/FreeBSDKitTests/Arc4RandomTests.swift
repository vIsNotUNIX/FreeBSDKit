/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit

final class Arc4RandomTests: XCTestCase {

    func testUInt32Generation() {
        let value1 = Arc4Random.uint32()
        let value2 = Arc4Random.uint32()
        // Two random UInt32s should (almost certainly) not be equal
        XCTAssertNotEqual(value1, value2)
    }

    func testUniformBound() {
        // Test that uniform respects bounds
        for _ in 0..<100 {
            let value = Arc4Random.uniform(10)
            XCTAssertLessThan(value, 10)
        }

        // Test with bound of 1 (should always return 0)
        for _ in 0..<10 {
            XCTAssertEqual(Arc4Random.uniform(1), 0)
        }
    }

    func testBytesGeneration() {
        let bytes = Arc4Random.bytes(32)
        XCTAssertEqual(bytes.count, 32)
        // Very unlikely all zeros
        XCTAssertFalse(bytes.allSatisfy { $0 == 0 })
    }

    func testFillBuffer() {
        var buffer = [UInt8](repeating: 0, count: 64)
        Arc4Random.fill(&buffer)
        XCTAssertFalse(buffer.allSatisfy { $0 == 0 })
    }

    func testValueGeneration() {
        let value1: UInt64 = Arc4Random.value()
        let value2: UInt64 = Arc4Random.value()
        XCTAssertNotEqual(value1, value2)

        let small1: UInt16 = Arc4Random.value()
        let small2: UInt16 = Arc4Random.value()
        // With 16 bits, there's a tiny chance of collision, but very unlikely
        _ = small1
        _ = small2
    }

    func testBool() {
        var trueCount = 0
        var falseCount = 0

        for _ in 0..<1000 {
            if Arc4Random.bool() {
                trueCount += 1
            } else {
                falseCount += 1
            }
        }

        // Should be roughly 50/50, allow wide margin
        XCTAssertGreaterThan(trueCount, 300)
        XCTAssertGreaterThan(falseCount, 300)
    }

    func testRangeInt() {
        for _ in 0..<100 {
            let value = Arc4Random.in(10..<20)
            XCTAssertGreaterThanOrEqual(value, 10)
            XCTAssertLessThan(value, 20)
        }
    }

    func testClosedRangeInt() {
        for _ in 0..<100 {
            let value = Arc4Random.in(1...6)
            XCTAssertGreaterThanOrEqual(value, 1)
            XCTAssertLessThanOrEqual(value, 6)
        }
    }

    func testShuffle() {
        let original = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        var array = original
        Arc4Random.shuffle(&array)

        // Should contain same elements
        XCTAssertEqual(Set(array), Set(original))

        // Should (almost certainly) be in different order
        // There's a 1/10! chance it stays the same
        XCTAssertNotEqual(array, original)
    }

    func testShuffled() {
        let original = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let shuffled = Arc4Random.shuffled(original)

        XCTAssertEqual(Set(shuffled), Set(original))
        XCTAssertNotEqual(shuffled, original)
    }

    func testElement() {
        let array = ["a", "b", "c", "d", "e"]

        for _ in 0..<100 {
            if let element = Arc4Random.element(from: array) {
                XCTAssertTrue(array.contains(element))
            } else {
                XCTFail("Should return an element")
            }
        }

        // Empty array should return nil
        let empty: [String] = []
        XCTAssertNil(Arc4Random.element(from: empty))
    }
}
