/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import AgeSignal

final class AgeBracketTests: XCTestCase {

    // MARK: - Raw Value Tests

    func testRawValues() {
        XCTAssertEqual(AgeBracket.under13.rawValue, 0x00)
        XCTAssertEqual(AgeBracket.age13to15.rawValue, 0x01)
        XCTAssertEqual(AgeBracket.age16to17.rawValue, 0x02)
        XCTAssertEqual(AgeBracket.adult.rawValue, 0x03)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(AgeBracket(rawValue: 0x00), .under13)
        XCTAssertEqual(AgeBracket(rawValue: 0x01), .age13to15)
        XCTAssertEqual(AgeBracket(rawValue: 0x02), .age16to17)
        XCTAssertEqual(AgeBracket(rawValue: 0x03), .adult)
        XCTAssertNil(AgeBracket(rawValue: 0x04))
        XCTAssertNil(AgeBracket(rawValue: 0xFF))
    }

    // MARK: - Description Tests

    func testDescription() {
        XCTAssertEqual(AgeBracket.under13.description, "under13")
        XCTAssertEqual(AgeBracket.age13to15.description, "13-15")
        XCTAssertEqual(AgeBracket.age16to17.description, "16-17")
        XCTAssertEqual(AgeBracket.adult.description, "18+")
    }

    func testHumanReadable() {
        XCTAssertEqual(AgeBracket.under13.humanReadable, "Under 13 years old")
        XCTAssertEqual(AgeBracket.age13to15.humanReadable, "13 to 15 years old")
        XCTAssertEqual(AgeBracket.age16to17.humanReadable, "16 to 17 years old")
        XCTAssertEqual(AgeBracket.adult.humanReadable, "18 years or older")
    }

    // MARK: - All Cases

    func testAllCases() {
        XCTAssertEqual(AgeBracket.allCases.count, 4)
        XCTAssertTrue(AgeBracket.allCases.contains(.under13))
        XCTAssertTrue(AgeBracket.allCases.contains(.age13to15))
        XCTAssertTrue(AgeBracket.allCases.contains(.age16to17))
        XCTAssertTrue(AgeBracket.allCases.contains(.adult))
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for bracket in AgeBracket.allCases {
            let data = try encoder.encode(bracket)
            let decoded = try decoder.decode(AgeBracket.self, from: data)
            XCTAssertEqual(bracket, decoded)
        }
    }
}

// MARK: - AgeSignalStatus Tests

final class AgeSignalStatusTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(AgeSignalStatus.ok.rawValue, 0x00)
        XCTAssertEqual(AgeSignalStatus.notSet.rawValue, 0x01)
        XCTAssertEqual(AgeSignalStatus.permissionDenied.rawValue, 0x02)
        XCTAssertEqual(AgeSignalStatus.unknownUser.rawValue, 0x03)
        XCTAssertEqual(AgeSignalStatus.invalidRequest.rawValue, 0x04)
        XCTAssertEqual(AgeSignalStatus.serviceUnavailable.rawValue, 0x05)
    }

    func testDescription() {
        XCTAssertEqual(AgeSignalStatus.ok.description, "ok")
        XCTAssertEqual(AgeSignalStatus.notSet.description, "not_set")
        XCTAssertEqual(AgeSignalStatus.permissionDenied.description, "permission_denied")
    }
}

// MARK: - AgeSignalResult Tests

final class AgeSignalResultTests: XCTestCase {

    func testEquality() {
        XCTAssertEqual(AgeSignalResult.bracket(.adult), AgeSignalResult.bracket(.adult))
        XCTAssertNotEqual(AgeSignalResult.bracket(.adult), AgeSignalResult.bracket(.under13))
        XCTAssertEqual(AgeSignalResult.notSet, AgeSignalResult.notSet)
        XCTAssertEqual(AgeSignalResult.permissionDenied, AgeSignalResult.permissionDenied)
        XCTAssertNotEqual(AgeSignalResult.notSet, AgeSignalResult.permissionDenied)
    }

    func testDescription() {
        XCTAssertEqual(AgeSignalResult.bracket(.adult).description, "bracket(18+)")
        XCTAssertEqual(AgeSignalResult.notSet.description, "notSet")
        XCTAssertEqual(AgeSignalResult.permissionDenied.description, "permissionDenied")
    }
}
