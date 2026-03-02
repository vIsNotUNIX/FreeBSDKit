/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import AgeSignal
import FPC

// MARK: - AgeSignalRequest Tests

final class AgeSignalRequestTests: XCTestCase {

    // MARK: - Query Own

    func testQueryOwnEncode() {
        let request = AgeSignalRequest.queryOwn
        let message = request.toMessage()

        XCTAssertEqual(message.id, .ageQueryOwn)
        XCTAssertEqual(message.payload.count, 0)
    }

    func testQueryOwnDecode() throws {
        let message = FPCMessage(id: .ageQueryOwn)
        let request = try AgeSignalRequest.from(message: message)

        if case .queryOwn = request {
            // Success
        } else {
            XCTFail("Expected .queryOwn, got \(request)")
        }
    }

    // MARK: - Query User

    func testQueryUserEncode() {
        let request = AgeSignalRequest.queryUser(uid: 1001)
        let message = request.toMessage()

        XCTAssertEqual(message.id, .ageQueryUser)
        XCTAssertEqual(message.payload.count, 4)

        // UID 1001 = 0x000003E9 in big-endian
        XCTAssertEqual(message.payload[0], 0x00)
        XCTAssertEqual(message.payload[1], 0x00)
        XCTAssertEqual(message.payload[2], 0x03)
        XCTAssertEqual(message.payload[3], 0xE9)
    }

    func testQueryUserDecode() throws {
        let payload = Data([0x00, 0x00, 0x03, 0xE9])  // UID 1001
        let message = FPCMessage(id: .ageQueryUser, payload: payload)
        let request = try AgeSignalRequest.from(message: message)

        if case .queryUser(let uid) = request {
            XCTAssertEqual(uid, 1001)
        } else {
            XCTFail("Expected .queryUser, got \(request)")
        }
    }

    func testQueryUserDecodeInvalidPayload() {
        let payload = Data([0x00, 0x00, 0x03])  // Only 3 bytes
        let message = FPCMessage(id: .ageQueryUser, payload: payload)

        XCTAssertThrowsError(try AgeSignalRequest.from(message: message))
    }

    // MARK: - Set Birthdate

    func testSetBirthdateEncode() throws {
        let birthdate = try Birthdate(year: 2010, month: 6, day: 15)
        let request = AgeSignalRequest.setBirthdate(uid: 1001, birthdate: birthdate)
        let message = request.toMessage()

        XCTAssertEqual(message.id, .ageSetBirthdate)
        XCTAssertEqual(message.payload.count, 6)

        // First 4 bytes: UID 1001
        XCTAssertEqual(message.payload[0], 0x00)
        XCTAssertEqual(message.payload[1], 0x00)
        XCTAssertEqual(message.payload[2], 0x03)
        XCTAssertEqual(message.payload[3], 0xE9)

        // Last 2 bytes: birthdate (should match serialized birthdate)
        let bdData = birthdate.serialize()
        XCTAssertEqual(message.payload[4], bdData[0])
        XCTAssertEqual(message.payload[5], bdData[1])
    }

    func testSetBirthdateDecode() throws {
        let birthdate = try Birthdate(year: 2010, month: 6, day: 15)
        let bdData = birthdate.serialize()

        var payload = Data([0x00, 0x00, 0x03, 0xE9])  // UID 1001
        payload.append(bdData)

        let message = FPCMessage(id: .ageSetBirthdate, payload: payload)
        let request = try AgeSignalRequest.from(message: message)

        if case .setBirthdate(let uid, let bd) = request {
            XCTAssertEqual(uid, 1001)
            XCTAssertEqual(bd.daysSinceEpoch, birthdate.daysSinceEpoch)
        } else {
            XCTFail("Expected .setBirthdate, got \(request)")
        }
    }

    func testSetBirthdateDecodeInvalidPayload() {
        let payload = Data([0x00, 0x00, 0x03, 0xE9, 0x00])  // Only 5 bytes
        let message = FPCMessage(id: .ageSetBirthdate, payload: payload)

        XCTAssertThrowsError(try AgeSignalRequest.from(message: message))
    }

    // MARK: - Remove

    func testRemoveEncode() {
        let request = AgeSignalRequest.remove(uid: 1001)
        let message = request.toMessage()

        XCTAssertEqual(message.id, .ageRemove)
        XCTAssertEqual(message.payload.count, 4)

        XCTAssertEqual(message.payload[0], 0x00)
        XCTAssertEqual(message.payload[1], 0x00)
        XCTAssertEqual(message.payload[2], 0x03)
        XCTAssertEqual(message.payload[3], 0xE9)
    }

    func testRemoveDecode() throws {
        let payload = Data([0x00, 0x00, 0x03, 0xE9])  // UID 1001
        let message = FPCMessage(id: .ageRemove, payload: payload)
        let request = try AgeSignalRequest.from(message: message)

        if case .remove(let uid) = request {
            XCTAssertEqual(uid, 1001)
        } else {
            XCTFail("Expected .remove, got \(request)")
        }
    }

    // MARK: - Unknown Message ID

    func testDecodeUnknownMessageID() {
        let message = FPCMessage(id: MessageID(rawValue: 999))

        XCTAssertThrowsError(try AgeSignalRequest.from(message: message))
    }

    // MARK: - Round Trip

    func testQueryOwnRoundTrip() throws {
        let original = AgeSignalRequest.queryOwn
        let message = original.toMessage()
        let decoded = try AgeSignalRequest.from(message: message)

        if case .queryOwn = decoded {
            // Success
        } else {
            XCTFail("Round trip failed")
        }
    }

    func testQueryUserRoundTrip() throws {
        let original = AgeSignalRequest.queryUser(uid: 65535)
        let message = original.toMessage()
        let decoded = try AgeSignalRequest.from(message: message)

        if case .queryUser(let uid) = decoded {
            XCTAssertEqual(uid, 65535)
        } else {
            XCTFail("Round trip failed")
        }
    }

    func testSetBirthdateRoundTrip() throws {
        let birthdate = try Birthdate(year: 1990, month: 12, day: 31)
        let original = AgeSignalRequest.setBirthdate(uid: 0, birthdate: birthdate)
        let message = original.toMessage()
        let decoded = try AgeSignalRequest.from(message: message)

        if case .setBirthdate(let uid, let bd) = decoded {
            XCTAssertEqual(uid, 0)
            XCTAssertEqual(bd.daysSinceEpoch, birthdate.daysSinceEpoch)
        } else {
            XCTFail("Round trip failed")
        }
    }

    func testRemoveRoundTrip() throws {
        let original = AgeSignalRequest.remove(uid: UInt32.max)
        let message = original.toMessage()
        let decoded = try AgeSignalRequest.from(message: message)

        if case .remove(let uid) = decoded {
            XCTAssertEqual(uid, UInt32.max)
        } else {
            XCTFail("Round trip failed")
        }
    }
}

// MARK: - AgeSignalResponse Tests

final class AgeSignalResponseTests: XCTestCase {

    // MARK: - Encode

    func testEncodeSuccess() {
        let response = AgeSignalResponse.success(.adult)
        let data = response.encode()

        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data[0], AgeSignalStatus.ok.rawValue)
        XCTAssertEqual(data[1], AgeBracket.adult.rawValue)
    }

    func testEncodeError() {
        let response = AgeSignalResponse.error(.permissionDenied)
        let data = response.encode()

        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data[0], AgeSignalStatus.permissionDenied.rawValue)
        XCTAssertEqual(data[1], 0xFF)  // No bracket
    }

    func testEncodeNotSet() {
        let response = AgeSignalResponse.error(.notSet)
        let data = response.encode()

        XCTAssertEqual(data[0], AgeSignalStatus.notSet.rawValue)
    }

    // MARK: - Decode

    func testDecodeSuccess() throws {
        let data = Data([AgeSignalStatus.ok.rawValue, AgeBracket.under13.rawValue])
        let response = try AgeSignalResponse.decode(from: data)

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.bracket, .under13)
    }

    func testDecodeError() throws {
        let data = Data([AgeSignalStatus.unknownUser.rawValue, 0xFF])
        let response = try AgeSignalResponse.decode(from: data)

        XCTAssertEqual(response.status, .unknownUser)
        XCTAssertNil(response.bracket)
    }

    func testDecodeInvalidSize() {
        let data = Data([0x00])  // Only 1 byte

        XCTAssertThrowsError(try AgeSignalResponse.decode(from: data))
    }

    func testDecodeInvalidStatus() {
        let data = Data([0xFF, 0x00])  // Invalid status code

        XCTAssertThrowsError(try AgeSignalResponse.decode(from: data))
    }

    // MARK: - Round Trip

    func testRoundTripAllBrackets() throws {
        for bracket in AgeBracket.allCases {
            let original = AgeSignalResponse.success(bracket)
            let data = original.encode()
            let decoded = try AgeSignalResponse.decode(from: data)

            XCTAssertEqual(decoded.status, .ok)
            XCTAssertEqual(decoded.bracket, bracket)
        }
    }

    func testRoundTripAllStatuses() throws {
        let statuses: [AgeSignalStatus] = [.notSet, .permissionDenied, .unknownUser, .invalidRequest, .serviceUnavailable]

        for status in statuses {
            let original = AgeSignalResponse.error(status)
            let data = original.encode()
            let decoded = try AgeSignalResponse.decode(from: data)

            XCTAssertEqual(decoded.status, status)
        }
    }

    // MARK: - toResult

    func testToResultBracket() {
        let response = AgeSignalResponse.success(.age13to15)
        let result = response.toResult()

        if case .bracket(let bracket) = result {
            XCTAssertEqual(bracket, .age13to15)
        } else {
            XCTFail("Expected .bracket")
        }
    }

    func testToResultNotSet() {
        let response = AgeSignalResponse.error(.notSet)
        let result = response.toResult()

        XCTAssertEqual(result, .notSet)
    }

    func testToResultPermissionDenied() {
        let response = AgeSignalResponse.error(.permissionDenied)
        let result = response.toResult()

        XCTAssertEqual(result, .permissionDenied)
    }

    func testToResultUnknownUser() {
        let response = AgeSignalResponse.error(.unknownUser)
        let result = response.toResult()

        XCTAssertEqual(result, .unknownUser)
    }

    func testToResultServiceUnavailable() {
        let response = AgeSignalResponse.error(.serviceUnavailable)
        let result = response.toResult()

        if case .error = result {
            // Success
        } else {
            XCTFail("Expected .error")
        }
    }

    // MARK: - OK Without Bracket (Remove case)

    func testOkWithoutBracket() {
        let response = AgeSignalResponse(status: .ok, bracket: nil)
        let result = response.toResult()

        // ok with no bracket means success (e.g., remove operation)
        XCTAssertEqual(result, .notSet)
    }
}

// MARK: - AgeSignalError Tests

final class AgeSignalErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(AgeSignalError.notConnected.errorDescription)
        XCTAssertNotNil(AgeSignalError.invalidResponse.errorDescription)
        XCTAssertNotNil(AgeSignalError.timeout.errorDescription)
        XCTAssertNotNil(AgeSignalError.protocolError("test").errorDescription)
        XCTAssertNotNil(AgeSignalError.invalidBirthdate("test").errorDescription)
        XCTAssertNotNil(AgeSignalError.userNotFound("test").errorDescription)
        XCTAssertNotNil(AgeSignalError.storageError("test").errorDescription)
        XCTAssertNotNil(AgeSignalError.permissionDenied("test").errorDescription)
    }

    func testConnectionFailedDescription() {
        let underlying = NSError(domain: "test", code: 1)
        let error = AgeSignalError.connectionFailed(underlying: underlying)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.description.contains("connect"))
    }
}
