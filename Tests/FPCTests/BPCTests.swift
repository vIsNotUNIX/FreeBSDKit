/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FPC
import Descriptors

// MARK: - BPC Tests

final class BPCTests: XCTestCase {

    // MARK: - Message Struct

    func testMessageDefaults() {
        let msg = FPCMessage(id: .ping)
        XCTAssertEqual(msg.id, .ping)
        XCTAssertEqual(msg.correlationID, 0)
        XCTAssertTrue(msg.payload.isEmpty)
        XCTAssertTrue(msg.descriptors.isEmpty)
    }

    func testMessageFactoryRequest() {
        let req = FPCMessage.request(.lookup, payload: Data("hello".utf8))
        XCTAssertEqual(req.id, .lookup)
        XCTAssertEqual(req.correlationID, 0)  // endpoint assigns this on send
        XCTAssertEqual(req.payload, Data("hello".utf8))
    }

    func testMessageFactoryReplyFromMessage() {
        let request = FPCMessage(id: .ping, correlationID: 42)
        let reply = FPCMessage.reply(to: request, id: .pong, payload: Data("response".utf8))
        XCTAssertEqual(reply.id, .pong)
        XCTAssertEqual(reply.correlationID, 42)
        XCTAssertEqual(reply.payload, Data("response".utf8))
    }

    func testMessageFactoryReplyFromToken() {
        let token = FPCReplyToken(correlationID: 123)
        let reply = FPCMessage.reply(to: token, id: .lookupReply)
        XCTAssertEqual(reply.id, .lookupReply)
        XCTAssertEqual(reply.correlationID, 123)
    }

    func testReplyToken() {
        let msg = FPCMessage(id: .ping, correlationID: 99)
        let token = msg.replyToken
        XCTAssertEqual(token.correlationID, 99)
    }

    func testMessageIDRawValues() {
        XCTAssertEqual(MessageID.ping.rawValue, 1)
        XCTAssertEqual(MessageID.pong.rawValue, 2)
        XCTAssertEqual(MessageID.lookup.rawValue, 3)
        XCTAssertEqual(MessageID.lookupReply.rawValue, 4)
        XCTAssertEqual(MessageID.subscribe.rawValue, 5)
        XCTAssertEqual(MessageID.subscribeAck.rawValue, 6)
        XCTAssertEqual(MessageID.event.rawValue, 7)
        XCTAssertEqual(MessageID.error.rawValue, 255)
    }

    func testMessageIDSpaceBoundaries() {
        XCTAssertTrue(MessageID.ping.isSystemReserved)
        XCTAssertFalse(MessageID.ping.isUserDefined)

        let userID = MessageID(rawValue: 256)
        XCTAssertFalse(userID.isSystemReserved)
        XCTAssertTrue(userID.isUserDefined)
    }

    func testMessageIDDescription() {
        XCTAssertEqual(MessageID.ping.description, "ping")
        XCTAssertEqual(MessageID.error.description, "error")
        XCTAssertEqual(MessageID(rawValue: 256).description, "user(256)")
        XCTAssertEqual(MessageID(rawValue: 100).description, "reserved(100)")
    }

    // MARK: - FPCError

    func testFPCErrorDescriptions() {
        XCTAssertTrue(FPCError.disconnected.description.contains("disconnect"))
        XCTAssertTrue(FPCError.stopped.description.contains("stopped"))
        XCTAssertTrue(FPCError.timeout.description.contains("timed out"))
        XCTAssertTrue(FPCError.tooManyDescriptors(300).description.contains("300"))
        XCTAssertTrue(FPCError.unsupportedVersion(5).description.contains("5"))
    }

    // MARK: - ConnectionState

    func testConnectionStateValues() {
        // Just verify the enum cases exist and are distinct
        let idle: ConnectionState = .idle
        let running: ConnectionState = .running
        let stopped: ConnectionState = .stopped

        XCTAssertNotEqual(idle, running)
        XCTAssertNotEqual(running, stopped)
        XCTAssertNotEqual(idle, stopped)
    }

    // MARK: - Wire Format Constants

    func testWireFormatConstants() {
        XCTAssertEqual(FPCFrameLayout.headerSize, 256)
        XCTAssertEqual(FPCFrameLayout.trailerSize, 256)
        XCTAssertEqual(FPCFrameLayout.minimumMessageSize, 512)
        XCTAssertEqual(FPCFrameLayout.maxDescriptors, 254)
        XCTAssertEqual(FPCFrameLayout.currentVersion, 0)
    }

    func testWireFormatOffsets() {
        XCTAssertEqual(FPCFrameLayout.messageIDOffset, 0)
        XCTAssertEqual(FPCFrameLayout.correlationIDOffset, 4)
        XCTAssertEqual(FPCFrameLayout.payloadLengthOffset, 12)
        XCTAssertEqual(FPCFrameLayout.descriptorCountOffset, 16)
        XCTAssertEqual(FPCFrameLayout.versionOffset, 17)
        XCTAssertEqual(FPCFrameLayout.flagsOffset, 18)
    }

    // MARK: - WireHeader Encoding

    func testWireHeaderEncodeBasic() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 42,
            payloadLength: 100,
            descriptorCount: 2
        )

        let data = header.encode()
        XCTAssertEqual(data.count, 256)

        // Verify fields at correct offsets
        let decodedMsgID = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        let decodedCorrID = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt64.self) }
        let decodedPayloadLen = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 12, as: UInt32.self) }

        XCTAssertEqual(decodedMsgID, 1)
        XCTAssertEqual(decodedCorrID, 42)
        XCTAssertEqual(decodedPayloadLen, 100)
        XCTAssertEqual(data[16], 2)  // descriptorCount
        XCTAssertEqual(data[17], 0)  // version
        XCTAssertEqual(data[18], 0)  // flags
    }

    func testWireHeaderEncodeWithOOLFlag() {
        let header = FPCFrameHeader(
            messageID: 7,
            correlationID: 12345678901234,
            payloadLength: 0,
            descriptorCount: 1,
            flags: FPCFrameLayout.flagOOLPayload
        )

        let data = header.encode()
        XCTAssertEqual(data[18], FPCFrameLayout.flagOOLPayload)
        XCTAssertTrue(header.hasOOLPayload)
    }

    func testWireHeaderEncodeLargeCorrelationID() {
        // Test 64-bit correlation ID near max value
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: UInt64.max - 1,
            payloadLength: 0,
            descriptorCount: 0
        )

        let data = header.encode()
        let decoded = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt64.self) }
        XCTAssertEqual(decoded, UInt64.max - 1)
    }

    // MARK: - WireHeader Decoding

    func testWireHeaderDecodeBasic() throws {
        var data = Data(count: 256)

        // Write fields
        var msgID: UInt32 = 255
        var corrID: UInt64 = 9876543210
        var payloadLen: UInt32 = 1024

        data.replaceSubrange(0..<4, with: Data(bytes: &msgID, count: 4))
        data.replaceSubrange(4..<12, with: Data(bytes: &corrID, count: 8))
        data.replaceSubrange(12..<16, with: Data(bytes: &payloadLen, count: 4))
        data[16] = 5   // descriptorCount
        data[17] = 0   // version
        data[18] = 0   // flags

        let header = try FPCFrameHeader.decode(from: data)

        XCTAssertEqual(header.messageID, 255)
        XCTAssertEqual(header.correlationID, 9876543210)
        XCTAssertEqual(header.payloadLength, 1024)
        XCTAssertEqual(header.descriptorCount, 5)
        XCTAssertEqual(header.version, 0)
        XCTAssertEqual(header.flags, 0)
        XCTAssertFalse(header.hasOOLPayload)
    }

    func testWireHeaderDecodeWithOOLFlag() throws {
        var data = Data(count: 256)
        data[18] = FPCFrameLayout.flagOOLPayload

        let header = try FPCFrameHeader.decode(from: data)
        XCTAssertTrue(header.hasOOLPayload)
    }

    func testWireHeaderDecodeTooShort() {
        let data = Data(count: 100)  // Less than 256

        XCTAssertThrowsError(try FPCFrameHeader.decode(from: data)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireHeaderRoundTrip() throws {
        let original = FPCFrameHeader(
            messageID: 12345,
            correlationID: 0xDEADBEEFCAFEBABE,
            payloadLength: 65535,
            descriptorCount: 254,
            version: 0,
            flags: FPCFrameLayout.flagOOLPayload
        )

        let data = original.encode()
        let decoded = try FPCFrameHeader.decode(from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - WireHeader Validation

    func testWireHeaderValidateSuccess() throws {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 42,
            payloadLength: 100,
            descriptorCount: 2
        )

        XCTAssertNoThrow(try header.validate())
    }

    func testWireHeaderValidateUnsupportedVersion() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 0,
            descriptorCount: 0,
            version: 99
        )

        XCTAssertThrowsError(try header.validate()) { error in
            if case FPCError.unsupportedVersion(let v) = error {
                XCTAssertEqual(v, 99)
            } else {
                XCTFail("Expected unsupportedVersion error")
            }
        }
    }

    func testWireHeaderValidateTooManyDescriptors() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 0,
            descriptorCount: 255  // Max is 254
        )

        XCTAssertThrowsError(try header.validate()) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireHeaderValidateOOLWithNonZeroPayload() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 100,  // Should be 0 for OOL
            descriptorCount: 1,
            flags: FPCFrameLayout.flagOOLPayload
        )

        XCTAssertThrowsError(try header.validate()) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireHeaderValidateOOLWithNoDescriptors() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 0,
            descriptorCount: 0,  // OOL requires at least 1
            flags: FPCFrameLayout.flagOOLPayload
        )

        XCTAssertThrowsError(try header.validate()) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    // MARK: - WireTrailer Encoding

    func testWireTrailerEncodeEmpty() {
        let trailer = FPCFrameTrailer(descriptorKinds: [])
        let data = trailer.encode()

        XCTAssertEqual(data.count, 256)
        // All bytes should be 0
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }

    func testWireTrailerEncodeWithDescriptors() {
        let trailer = FPCFrameTrailer(descriptorKinds: [1, 4, 8])  // file, socket, shm
        let data = trailer.encode()

        XCTAssertEqual(data[0], 1)
        XCTAssertEqual(data[1], 4)
        XCTAssertEqual(data[2], 8)
        XCTAssertEqual(data[3], 0)  // Rest should be 0
    }

    func testWireTrailerEncodeWithOOL() {
        let trailer = FPCFrameTrailer(descriptorKinds: [8, 1])  // shm (will become OOL), file
        let data = trailer.encode(hasOOLPayload: true)

        XCTAssertEqual(data[0], 255)  // OOL marker
        XCTAssertEqual(data[1], 1)    // file
    }

    // MARK: - WireTrailer Decoding

    func testWireTrailerDecodeEmpty() throws {
        let data = Data(count: 256)
        let trailer = try FPCFrameTrailer.decode(from: data, descriptorCount: 0)

        XCTAssertTrue(trailer.descriptorKinds.isEmpty)
    }

    func testWireTrailerDecodeWithDescriptors() throws {
        var data = Data(count: 256)
        data[0] = 1  // file
        data[1] = 4  // socket
        data[2] = 5  // pipe

        let trailer = try FPCFrameTrailer.decode(from: data, descriptorCount: 3)

        XCTAssertEqual(trailer.descriptorKinds, [1, 4, 5])
    }

    func testWireTrailerDecodeTooShort() {
        let data = Data(count: 100)

        XCTAssertThrowsError(try FPCFrameTrailer.decode(from: data, descriptorCount: 1)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireTrailerRoundTrip() throws {
        let original = FPCFrameTrailer(descriptorKinds: [1, 2, 3, 4, 5, 6, 7, 8, 9])
        let data = original.encode()
        let decoded = try FPCFrameTrailer.decode(from: data, descriptorCount: 9)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - WireTrailer Validation

    func testWireTrailerValidateSuccess() throws {
        let trailer = FPCFrameTrailer(descriptorKinds: [1, 4, 8])
        XCTAssertNoThrow(try trailer.validate(hasOOLPayload: false))
    }

    func testWireTrailerValidateOOLMarkerNotAtIndex0() {
        let trailer = FPCFrameTrailer(descriptorKinds: [1, 255])  // OOL marker at wrong position

        XCTAssertThrowsError(try trailer.validate(hasOOLPayload: false)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireTrailerValidateOOLExpectedButMissing() {
        let trailer = FPCFrameTrailer(descriptorKinds: [1])  // Should be 255 for OOL

        XCTAssertThrowsError(try trailer.validate(hasOOLPayload: true)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireTrailerValidateOOLCorrect() throws {
        let trailer = FPCFrameTrailer(descriptorKinds: [255, 1, 4])
        XCTAssertNoThrow(try trailer.validate(hasOOLPayload: true))
    }

    // MARK: - WireMessage Encoding

    func testWireMessageEncodeMinimal() {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 0,
            descriptorCount: 0
        )
        let msg = FPCFrame(header: header, payload: Data(), trailer: FPCFrameTrailer())
        let data = msg.encode()

        XCTAssertEqual(data.count, 512)  // 256 + 0 + 256
    }

    func testWireMessageEncodeWithPayload() {
        let payload = Data("Hello, BPC!".utf8)
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 42,
            payloadLength: UInt32(payload.count),
            descriptorCount: 0
        )
        let msg = FPCFrame(header: header, payload: payload, trailer: FPCFrameTrailer())
        let data = msg.encode()

        XCTAssertEqual(data.count, 512 + payload.count)

        // Verify payload is at correct position
        let extractedPayload = Data(data[256..<(256 + payload.count)])
        XCTAssertEqual(extractedPayload, payload)
    }

    func testWireMessageFromBPCMessage() {
        let bpcMessage = FPCMessage(
            id: .ping,
            correlationID: 12345,
            payload: Data([1, 2, 3, 4])
        )

        let wireMsg = FPCFrame(from: bpcMessage)

        XCTAssertEqual(wireMsg.header.messageID, MessageID.ping.rawValue)
        XCTAssertEqual(wireMsg.header.correlationID, 12345)
        XCTAssertEqual(wireMsg.header.payloadLength, 4)
        XCTAssertEqual(wireMsg.payload, Data([1, 2, 3, 4]))
    }

    // MARK: - WireMessage Decoding

    func testWireMessageDecodeMinimal() throws {
        let header = FPCFrameHeader(
            messageID: 2,
            correlationID: 99,
            payloadLength: 0,
            descriptorCount: 0
        )
        let original = FPCFrame(header: header, payload: Data(), trailer: FPCFrameTrailer())
        let encoded = original.encode()

        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.header.messageID, 2)
        XCTAssertEqual(decoded.header.correlationID, 99)
        XCTAssertTrue(decoded.payload.isEmpty)
    }

    func testWireMessageDecodeWithPayload() throws {
        let payload = Data(repeating: 0xAB, count: 1000)
        let header = FPCFrameHeader(
            messageID: 3,
            correlationID: 0,
            payloadLength: 1000,
            descriptorCount: 0
        )
        let original = FPCFrame(header: header, payload: payload, trailer: FPCFrameTrailer())
        let encoded = original.encode()

        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.payload.count, 1000)
        XCTAssertEqual(decoded.payload, payload)
    }

    func testWireMessageDecodeTooShort() {
        let data = Data(count: 400)  // Less than minimum 512

        XCTAssertThrowsError(try FPCFrame.decode(from: data)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireMessageDecodeWrongSize() {
        // Create valid header claiming 100 bytes payload
        var data = Data(count: 256)
        var payloadLen: UInt32 = 100
        data.replaceSubrange(12..<16, with: Data(bytes: &payloadLen, count: 4))

        // But only add 50 bytes payload + trailer
        data.append(Data(count: 50))
        data.append(Data(count: 256))

        XCTAssertThrowsError(try FPCFrame.decode(from: data)) { error in
            XCTAssertEqual(error as? FPCError, FPCError.invalidMessageFormat)
        }
    }

    func testWireMessageRoundTrip() throws {
        let payload = Data("Test payload with some data!".utf8)
        let header = FPCFrameHeader(
            messageID: 42,
            correlationID: 0xCAFEBABE,
            payloadLength: UInt32(payload.count),
            descriptorCount: 3
        )
        let trailer = FPCFrameTrailer(descriptorKinds: [1, 4, 8])
        let original = FPCFrame(header: header, payload: payload, trailer: trailer)

        let encoded = original.encode()
        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.header, original.header)
        XCTAssertEqual(decoded.payload, original.payload)
        XCTAssertEqual(decoded.trailer, original.trailer)
    }

    func testWireMessageToMessage() throws {
        let header = FPCFrameHeader(
            messageID: MessageID.pong.rawValue,
            correlationID: 777,
            payloadLength: 5,
            descriptorCount: 0
        )
        let wireMsg = FPCFrame(
            header: header,
            payload: Data("hello".utf8),
            trailer: FPCFrameTrailer()
        )

        let bpcMessage = wireMsg.toMessage()

        XCTAssertEqual(bpcMessage.id, .pong)
        XCTAssertEqual(bpcMessage.correlationID, 777)
        XCTAssertEqual(bpcMessage.payload, Data("hello".utf8))
    }

    // MARK: - Edge Cases

    func testWireMessageMaxPayloadLength() throws {
        // Test with a large payload (but not too large for test)
        let payload = Data(repeating: 0xFF, count: 65536)
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 65536,
            descriptorCount: 0
        )
        let original = FPCFrame(header: header, payload: payload, trailer: FPCFrameTrailer())

        let encoded = original.encode()
        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.payload.count, 65536)
    }

    func testWireMessageMaxDescriptors() throws {
        let kinds = Array(repeating: UInt8(1), count: 254)
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: 0,
            payloadLength: 0,
            descriptorCount: 254
        )
        let trailer = FPCFrameTrailer(descriptorKinds: kinds)
        let original = FPCFrame(header: header, payload: Data(), trailer: trailer)

        let encoded = original.encode()
        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.trailer.descriptorKinds.count, 254)
    }

    func testCorrelationIDZeroIsUnsolicited() {
        let msg = FPCMessage(id: .event, correlationID: 0)
        let wireMsg = FPCFrame(from: msg)

        XCTAssertEqual(wireMsg.header.correlationID, 0)
    }

    func testCorrelationIDMaxValue() throws {
        let header = FPCFrameHeader(
            messageID: 1,
            correlationID: UInt64.max,
            payloadLength: 0,
            descriptorCount: 0
        )
        let original = FPCFrame(header: header, payload: Data(), trailer: FPCFrameTrailer())

        let encoded = original.encode()
        let decoded = try FPCFrame.decode(from: encoded)

        XCTAssertEqual(decoded.header.correlationID, UInt64.max)
    }
}
