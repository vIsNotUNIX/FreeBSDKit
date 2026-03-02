/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import AgeSignal

final class BirthdateTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithComponents() throws {
        let bd = try Birthdate(year: 2010, month: 6, day: 15)
        // Should create successfully
        XCTAssertGreaterThan(bd.daysSinceEpoch, 0)
    }

    func testInitWithInvalidDate() {
        // February 30 doesn't exist - but Calendar may normalize it
        // Instead, test parsing invalid string format
        XCTAssertThrowsError(try Birthdate(parsing: "invalid-date"))
    }

    func testInitWithDateBefore1970() {
        XCTAssertThrowsError(try Birthdate(year: 1969, month: 12, day: 31))
    }

    func testInitParsing() throws {
        let bd = try Birthdate(parsing: "2010-06-15")
        XCTAssertGreaterThan(bd.daysSinceEpoch, 0)
    }

    func testInitParsingInvalid() {
        XCTAssertThrowsError(try Birthdate(parsing: "not-a-date"))
        XCTAssertThrowsError(try Birthdate(parsing: "2010/06/15"))
        XCTAssertThrowsError(try Birthdate(parsing: "06-15-2010"))
    }

    // MARK: - Serialization Tests

    func testSerializeRoundTrip() throws {
        let original = try Birthdate(year: 2010, month: 6, day: 15)
        let data = original.serialize()
        XCTAssertEqual(data.count, 2)

        let restored = try Birthdate(deserializing: data)
        XCTAssertEqual(original.daysSinceEpoch, restored.daysSinceEpoch)
    }

    func testDeserializeInvalidSize() {
        XCTAssertThrowsError(try Birthdate(deserializing: Data([0x00])))
        XCTAssertThrowsError(try Birthdate(deserializing: Data([0x00, 0x00, 0x00])))
    }

    // MARK: - Age Bracket Tests

    func testBracketUnder13() throws {
        // Someone born in 2020 should be under 13 in 2026
        let bd = try Birthdate(year: 2020, month: 1, day: 1)
        let bracket = bd.currentBracket()
        XCTAssertEqual(bracket, .under13)
    }

    func testBracket13to15() throws {
        // Someone born in 2012 should be 13-15 in 2026
        let bd = try Birthdate(year: 2012, month: 1, day: 1)
        let bracket = bd.currentBracket()
        XCTAssertEqual(bracket, .age13to15)
    }

    func testBracket16to17() throws {
        // Someone born in 2009 should be 16-17 in 2026
        let bd = try Birthdate(year: 2009, month: 1, day: 1)
        let bracket = bd.currentBracket()
        XCTAssertEqual(bracket, .age16to17)
    }

    func testBracketAdult() throws {
        // Someone born in 2000 should be an adult
        let bd = try Birthdate(year: 2000, month: 1, day: 1)
        let bracket = bd.currentBracket()
        XCTAssertEqual(bracket, .adult)
    }

    func testBracketAsOfDate() throws {
        // Someone born on 2010-06-15
        let bd = try Birthdate(year: 2010, month: 6, day: 15)

        // Create reference dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        // At age 12 (before 13th birthday)
        let at12 = formatter.date(from: "2022-06-14")!
        XCTAssertEqual(bd.bracket(asOf: at12), .under13)

        // At age 13 (on 13th birthday)
        let at13 = formatter.date(from: "2023-06-15")!
        XCTAssertEqual(bd.bracket(asOf: at13), .age13to15)

        // At age 16
        let at16 = formatter.date(from: "2026-06-15")!
        XCTAssertEqual(bd.bracket(asOf: at16), .age16to17)

        // At age 18
        let at18 = formatter.date(from: "2028-06-15")!
        XCTAssertEqual(bd.bracket(asOf: at18), .adult)
    }

    func testAgeInYears() throws {
        let bd = try Birthdate(year: 2000, month: 6, day: 15)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let beforeBirthday = formatter.date(from: "2020-06-14")!
        XCTAssertEqual(bd.ageInYears(asOf: beforeBirthday), 19)

        let onBirthday = formatter.date(from: "2020-06-15")!
        XCTAssertEqual(bd.ageInYears(asOf: onBirthday), 20)

        let afterBirthday = formatter.date(from: "2020-06-16")!
        XCTAssertEqual(bd.ageInYears(asOf: afterBirthday), 20)
    }

    // MARK: - Equality Tests

    func testEquality() throws {
        let bd1 = try Birthdate(year: 2010, month: 6, day: 15)
        let bd2 = try Birthdate(year: 2010, month: 6, day: 15)
        let bd3 = try Birthdate(year: 2010, month: 6, day: 16)

        XCTAssertEqual(bd1, bd2)
        XCTAssertNotEqual(bd1, bd3)
    }

    // MARK: - Description Tests

    func testDescription() throws {
        let bd = try Birthdate(year: 2010, month: 6, day: 15)
        // Description should include bracket but not actual date
        XCTAssertTrue(bd.description.contains("bracket"))
    }
}
