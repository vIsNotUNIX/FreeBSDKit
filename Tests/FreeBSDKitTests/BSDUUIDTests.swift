/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit

final class BSDUUIDTests: XCTestCase {

    // MARK: - Generation Tests

    func testGenerateSingle() throws {
        let uuid = try BSDUUID()
        XCTAssertFalse(uuid.isNil)
        XCTAssertEqual(uuid.byteArray.count, 16)
    }

    func testGenerateMultiple() throws {
        let uuids = try BSDUUID.generate(count: 10)
        XCTAssertEqual(uuids.count, 10)

        // All should be unique
        let unique = Set(uuids)
        XCTAssertEqual(unique.count, 10)
    }

    func testGenerateBatch() throws {
        // Batch generation should produce sequential UUIDs
        let uuids = try BSDUUID.generate(count: 5)

        // They should all be different
        for i in 0..<uuids.count {
            for j in (i+1)..<uuids.count {
                XCTAssertNotEqual(uuids[i], uuids[j])
            }
        }
    }

    func testGenerateInvalidCount() {
        XCTAssertThrowsError(try BSDUUID.generate(count: 0))
        XCTAssertThrowsError(try BSDUUID.generate(count: -1))
        XCTAssertThrowsError(try BSDUUID.generate(count: 2049))
        XCTAssertThrowsError(try BSDUUID.generate(count: 3000))
    }

    func testGenerateBoundary() throws {
        // Test boundary: exactly 1
        let one = try BSDUUID.generate(count: 1)
        XCTAssertEqual(one.count, 1)
        XCTAssertFalse(one[0].isNil)

        // Test boundary: exactly 2048 (max)
        let max = try BSDUUID.generate(count: 2048)
        XCTAssertEqual(max.count, 2048)
        XCTAssertEqual(Set(max).count, 2048)  // All unique
    }

    // MARK: - Parsing Tests

    func testParseHyphenated() throws {
        let uuid = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(uuid.string, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testParseCompactNotSupported() {
        // FreeBSD's uuid_from_string only accepts hyphenated format
        XCTAssertThrowsError(try BSDUUID(string: "550e8400e29b41d4a716446655440000"))
    }

    func testParseUppercase() throws {
        let uuid = try BSDUUID(string: "550E8400-E29B-41D4-A716-446655440000")
        XCTAssertEqual(uuid.string.lowercased(), "550e8400-e29b-41d4-a716-446655440000")
    }

    func testParseInvalid() {
        XCTAssertThrowsError(try BSDUUID(string: "not-a-uuid"))
        XCTAssertThrowsError(try BSDUUID(string: "550e8400-e29b-41d4-a716"))
    }

    func testParseEmpty() throws {
        // Empty string parses as nil UUID in FreeBSD
        let uuid = try BSDUUID(string: "")
        XCTAssertTrue(uuid.isNil)
    }

    // MARK: - Nil UUID Tests

    func testNilUUID() {
        let uuid = BSDUUID.zero
        XCTAssertTrue(uuid.isNil)
        XCTAssertEqual(uuid.string, "00000000-0000-0000-0000-000000000000")
    }

    func testGeneratedNotNil() throws {
        let uuid = try BSDUUID()
        XCTAssertFalse(uuid.isNil)
    }

    // MARK: - Byte Array Tests

    func testFromBytes() throws {
        let bytes: [UInt8] = [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
                              0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00]
        let uuid = try BSDUUID(bytes: bytes)
        XCTAssertEqual(uuid.byteArray, bytes)
    }

    func testFromBytesInvalidLength() {
        // Too short
        let shortBytes: [UInt8] = [0x55, 0x0e, 0x84]
        XCTAssertThrowsError(try BSDUUID(bytes: shortBytes)) { error in
            guard case UUIDError.invalidLength(3) = error else {
                XCTFail("Expected invalidLength error")
                return
            }
        }

        // Too long
        let longBytes: [UInt8] = Array(repeating: 0x42, count: 20)
        XCTAssertThrowsError(try BSDUUID(bytes: longBytes)) { error in
            guard case UUIDError.invalidLength(20) = error else {
                XCTFail("Expected invalidLength error")
                return
            }
        }

        // Empty
        let emptyBytes: [UInt8] = []
        XCTAssertThrowsError(try BSDUUID(bytes: emptyBytes)) { error in
            guard case UUIDError.invalidLength(0) = error else {
                XCTFail("Expected invalidLength error")
                return
            }
        }
    }

    func testByteArrayRoundtrip() throws {
        let uuid = try BSDUUID()
        let bytes = uuid.byteArray
        let restored = try BSDUUID(bytes: bytes)
        XCTAssertEqual(uuid, restored)
    }

    // MARK: - String Tests

    func testStringFormat() throws {
        let uuid = try BSDUUID()
        let str = uuid.string

        // Should be 36 characters: 8-4-4-4-12
        XCTAssertEqual(str.count, 36)
        XCTAssertEqual(str.filter { $0 == "-" }.count, 4)
    }

    func testCompactString() throws {
        let uuid = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(uuid.compactString, "550e8400e29b41d4a716446655440000")
    }

    func testStringRoundtrip() throws {
        let uuid = try BSDUUID()
        let str = uuid.string
        let parsed = try BSDUUID(string: str)
        XCTAssertEqual(uuid, parsed)
    }

    // MARK: - Version and Variant Tests

    func testVersion1() throws {
        // Generated UUIDs should be version 1 (time-based)
        let uuid = try BSDUUID()
        XCTAssertEqual(uuid.version, 1)
    }

    func testVariantRFC4122() throws {
        let uuid = try BSDUUID()
        XCTAssertEqual(uuid.variant, .rfc4122)
    }

    func testVersion4FromString() throws {
        // A known version 4 UUID
        let uuid = try BSDUUID(string: "f47ac10b-58cc-4372-a567-0e02b2c3d479")
        XCTAssertEqual(uuid.version, 4)
        XCTAssertEqual(uuid.variant, .rfc4122)
    }

    func testNilUUIDVersion() {
        // Nil UUID has version 0
        XCTAssertEqual(BSDUUID.zero.version, 0)
    }

    func testVariantNCS() throws {
        // NCS variant: high bit of byte 8 is 0 (0x0X - 0x7X)
        let bytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0x10, 0, 0x00, 0, 0, 0, 0, 0, 0, 0]
        let uuid = try BSDUUID(bytes: bytes)
        XCTAssertEqual(uuid.variant, .ncs)
    }

    func testVariantMicrosoft() throws {
        // Microsoft variant: bits 110X XXXX (0xC0 - 0xDF)
        let bytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0x10, 0, 0xC0, 0, 0, 0, 0, 0, 0, 0]
        let uuid = try BSDUUID(bytes: bytes)
        XCTAssertEqual(uuid.variant, .microsoft)
    }

    func testVariantFuture() throws {
        // Future variant: bits 111X XXXX (0xE0 - 0xFF)
        let bytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0x10, 0, 0xE0, 0, 0, 0, 0, 0, 0, 0]
        let uuid = try BSDUUID(bytes: bytes)
        XCTAssertEqual(uuid.variant, .future)
    }

    // MARK: - Comparison Tests

    func testEquality() throws {
        let uuid1 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        let uuid2 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(uuid1, uuid2)
    }

    func testInequality() throws {
        let uuid1 = try BSDUUID()
        let uuid2 = try BSDUUID()
        XCTAssertNotEqual(uuid1, uuid2)
    }

    func testComparable() throws {
        let uuid1 = try BSDUUID(string: "00000000-0000-0000-0000-000000000001")
        let uuid2 = try BSDUUID(string: "00000000-0000-0000-0000-000000000002")
        XCTAssertLessThan(uuid1, uuid2)
    }

    func testSorting() throws {
        let uuids = try BSDUUID.generate(count: 5)
        let sorted = uuids.sorted()

        for i in 0..<(sorted.count - 1) {
            XCTAssertLessThanOrEqual(sorted[i], sorted[i + 1])
        }
    }

    // MARK: - Hashable Tests

    func testHashable() throws {
        let uuid1 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        let uuid2 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")

        var set = Set<BSDUUID>()
        set.insert(uuid1)
        set.insert(uuid2)

        XCTAssertEqual(set.count, 1)
    }

    func testDictionaryKey() throws {
        let uuid = try BSDUUID()
        var dict: [BSDUUID: String] = [:]
        dict[uuid] = "test"
        XCTAssertEqual(dict[uuid], "test")
    }

    func testHashConsistency() throws {
        // Same UUID should always produce same hash
        let uuid1 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        let uuid2 = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")

        XCTAssertEqual(uuid1.hashValue, uuid2.hashValue)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let uuid = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        let encoder = JSONEncoder()
        let data = try encoder.encode(uuid)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BSDUUID.self, from: data)

        XCTAssertEqual(uuid, decoded)
    }

    func testEncodeFormat() throws {
        let uuid = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        let encoder = JSONEncoder()
        let data = try encoder.encode(uuid)
        let jsonString = String(data: data, encoding: .utf8)!

        // Should encode as a quoted string
        XCTAssertTrue(jsonString.contains("550e8400-e29b-41d4-a716-446655440000"))
    }

    func testDecodeInvalidJSON() throws {
        let decoder = JSONDecoder()

        // Invalid UUID string
        let invalidData = "\"not-a-uuid\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(BSDUUID.self, from: invalidData))

        // Number instead of string
        let numberData = "12345".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(BSDUUID.self, from: numberData))
    }

    func testEncodeDecodeNil() throws {
        let uuid = BSDUUID.zero
        let encoder = JSONEncoder()
        let data = try encoder.encode(uuid)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BSDUUID.self, from: data)

        XCTAssertEqual(uuid, decoded)
        XCTAssertTrue(decoded.isNil)
    }

    // MARK: - Description Tests

    func testDescription() throws {
        let uuid = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(uuid.description, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual("\(uuid)", "550e8400-e29b-41d4-a716-446655440000")
    }
}
