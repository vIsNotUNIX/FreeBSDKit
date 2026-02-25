/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors

// MARK: - Wire Format
//
// Layout: 256-byte fixed header | variable payload | 256-byte fixed trailer
//
// IMPORTANT: Version 0 uses host-endian encoding for multi-byte fields.
// Endpoints MUST be same-host, same-ABI. Do NOT persist frames or send
// across architectures. This is acceptable for local Unix-domain IPC only.
//
// Header (256 bytes):
//   - messageID (UInt32):        4 bytes at offset 0  (host-endian)
//   - correlationID (UInt64):    8 bytes at offset 4  (host-endian, 0 = unsolicited)
//   - payloadLength (UInt32):    4 bytes at offset 12 (host-endian, 0 if OOL)
//   - descriptorCount (UInt8):   1 byte  at offset 16 (max 254)
//   - version (UInt8):           1 byte  at offset 17 (currently 0)
//   - flags (UInt8):             1 byte  at offset 18
//       - bit 0: hasOOLPayload (1 if payload sent via shared memory)
//       - bits 1-7: reserved
//   - reserved:                237 bytes at offset 19-255
//
// Trailer (256 bytes):
//   - descriptorKinds: 254 bytes at offset 0-253 (one per descriptor)
//       - Each byte encodes DescriptorKind.wireValue
//       - Value 255 marks the out-of-line payload descriptor (index 0 only)
//   - reserved:          2 bytes at offset 254-255

/// Wire format constants and utilities for BPC protocol.
public enum WireFormat {
    /// Size of the fixed header in bytes.
    public static let headerSize = 256

    /// Size of the fixed trailer in bytes.
    public static let trailerSize = 256

    /// Minimum valid message size (header + trailer, no payload).
    public static let minimumMessageSize = headerSize + trailerSize

    /// Maximum number of descriptors per message.
    public static let maxDescriptors = 254

    /// Current protocol version.
    public static let currentVersion: UInt8 = 0

    // Header field offsets
    public static let messageIDOffset = 0
    public static let correlationIDOffset = 4
    public static let payloadLengthOffset = 12
    public static let descriptorCountOffset = 16
    public static let versionOffset = 17
    public static let flagsOffset = 18

    // Flag bits
    public static let flagOOLPayload: UInt8 = 0x01
}

// MARK: - WireHeader

/// Parsed header from the wire format.
public struct WireHeader: Equatable, Sendable {
    public var messageID: UInt32
    public var correlationID: UInt64
    public var payloadLength: UInt32
    public var descriptorCount: UInt8
    public var version: UInt8
    public var flags: UInt8

    public var hasOOLPayload: Bool {
        (flags & WireFormat.flagOOLPayload) != 0
    }

    public init(
        messageID: UInt32,
        correlationID: UInt64,
        payloadLength: UInt32,
        descriptorCount: UInt8,
        version: UInt8 = WireFormat.currentVersion,
        flags: UInt8 = 0
    ) {
        self.messageID = messageID
        self.correlationID = correlationID
        self.payloadLength = payloadLength
        self.descriptorCount = descriptorCount
        self.version = version
        self.flags = flags
    }

    /// Encodes the header to wire format bytes.
    public func encode() -> Data {
        var header = Data(count: WireFormat.headerSize)

        var msgID = messageID
        header.replaceSubrange(0..<4, with: Data(bytes: &msgID, count: 4))

        var corrID = correlationID
        header.replaceSubrange(4..<12, with: Data(bytes: &corrID, count: 8))

        var payloadLen = payloadLength
        header.replaceSubrange(12..<16, with: Data(bytes: &payloadLen, count: 4))

        header[16] = descriptorCount
        header[17] = version
        header[18] = flags

        return header
    }

    /// Decodes a header from wire format bytes.
    ///
    /// - Parameter data: At least 256 bytes of header data
    /// - Returns: Parsed header
    /// - Throws: `FPCError.invalidMessageFormat` if data is too short
    public static func decode(from data: Data) throws -> WireHeader {
        guard data.count >= WireFormat.headerSize else {
            throw FPCError.invalidMessageFormat
        }

        let messageID = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: WireFormat.messageIDOffset, as: UInt32.self)
        }

        let correlationID = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: WireFormat.correlationIDOffset, as: UInt64.self)
        }

        let payloadLength = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: WireFormat.payloadLengthOffset, as: UInt32.self)
        }

        let descriptorCount = data[WireFormat.descriptorCountOffset]
        let version = data[WireFormat.versionOffset]
        let flags = data[WireFormat.flagsOffset]

        return WireHeader(
            messageID: messageID,
            correlationID: correlationID,
            payloadLength: payloadLength,
            descriptorCount: descriptorCount,
            version: version,
            flags: flags
        )
    }

    /// Validates the header for protocol compliance.
    ///
    /// - Throws: `FPCError` describing the validation failure
    public func validate() throws {
        // Check version
        guard version == WireFormat.currentVersion else {
            throw FPCError.unsupportedVersion(version)
        }

        // Check descriptor count
        guard descriptorCount <= WireFormat.maxDescriptors else {
            throw FPCError.invalidMessageFormat
        }

        // OOL payload consistency checks
        if hasOOLPayload {
            // If OOL flag is set, inline payload length must be 0
            guard payloadLength == 0 else {
                throw FPCError.invalidMessageFormat
            }
            // OOL requires at least one descriptor (the shm)
            guard descriptorCount >= 1 else {
                throw FPCError.invalidMessageFormat
            }
        }
    }
}

// MARK: - WireTrailer

/// Parsed trailer from the wire format.
public struct WireTrailer: Equatable, Sendable {
    /// Descriptor kinds, one per descriptor (max 254).
    public var descriptorKinds: [UInt8]

    public init(descriptorKinds: [UInt8] = []) {
        self.descriptorKinds = descriptorKinds
    }

    /// Encodes the trailer to wire format bytes.
    ///
    /// - Parameter hasOOLPayload: If true, first descriptor kind is marked as OOL (255)
    public func encode(hasOOLPayload: Bool = false) -> Data {
        var trailer = Data(count: WireFormat.trailerSize)

        for (index, kind) in descriptorKinds.enumerated() {
            guard index < WireFormat.maxDescriptors else { break }
            if index == 0 && hasOOLPayload {
                trailer[index] = DescriptorKind.oolPayloadWireValue
            } else {
                trailer[index] = kind
            }
        }

        return trailer
    }

    /// Decodes a trailer from wire format bytes.
    ///
    /// - Parameters:
    ///   - data: At least 256 bytes of trailer data
    ///   - descriptorCount: Number of descriptors to read
    /// - Returns: Parsed trailer
    /// - Throws: `FPCError.invalidMessageFormat` if data is too short
    public static func decode(from data: Data, descriptorCount: Int) throws -> WireTrailer {
        guard data.count >= WireFormat.trailerSize else {
            throw FPCError.invalidMessageFormat
        }

        // Copy trailer data to reset indices (Data slice keeps original indices)
        let trailer = Data(data.prefix(WireFormat.trailerSize))

        var kinds: [UInt8] = []
        for i in 0..<min(descriptorCount, WireFormat.maxDescriptors) {
            kinds.append(trailer[i])
        }

        return WireTrailer(descriptorKinds: kinds)
    }

    /// Validates the trailer for protocol compliance.
    ///
    /// - Parameter hasOOLPayload: Whether OOL payload flag is set in header
    /// - Throws: `FPCError` describing the validation failure
    public func validate(hasOOLPayload: Bool) throws {
        for (index, kind) in descriptorKinds.enumerated() {
            // Only index 0 may have OOL marker (255) when hasOOLPayload
            if kind == DescriptorKind.oolPayloadWireValue {
                guard hasOOLPayload && index == 0 else {
                    throw FPCError.invalidMessageFormat
                }
            }
        }

        // If OOL is expected, first descriptor must be OOL marker
        if hasOOLPayload && !descriptorKinds.isEmpty {
            guard descriptorKinds[0] == DescriptorKind.oolPayloadWireValue else {
                throw FPCError.invalidMessageFormat
            }
        }
    }
}

// MARK: - WireMessage

/// A complete wire-format message (header + payload + trailer).
public struct WireMessage: Equatable, Sendable {
    public var header: WireHeader
    public var payload: Data
    public var trailer: WireTrailer

    public init(header: WireHeader, payload: Data, trailer: WireTrailer) {
        self.header = header
        self.payload = payload
        self.trailer = trailer
    }

    /// Creates a wire message from a BPC Message.
    ///
    /// - Parameters:
    ///   - message: The message to encode
    ///   - useOOL: If true, marks payload as out-of-line (caller handles shm)
    public init(from message: Message, useOOL: Bool = false) {
        let flags: UInt8 = useOOL ? WireFormat.flagOOLPayload : 0
        let payloadLength: UInt32 = useOOL ? 0 : UInt32(message.payload.count)

        self.header = WireHeader(
            messageID: message.id.rawValue,
            correlationID: message.correlationID,
            payloadLength: payloadLength,
            descriptorCount: UInt8(min(message.descriptors.count, WireFormat.maxDescriptors)),
            flags: flags
        )

        self.payload = useOOL ? Data() : message.payload

        let kinds = message.descriptors.prefix(WireFormat.maxDescriptors).map { $0.kind.wireValue }
        self.trailer = WireTrailer(descriptorKinds: Array(kinds))
    }

    /// Encodes the complete message to wire format bytes.
    public func encode() -> Data {
        var data = header.encode()
        data.append(payload)
        data.append(trailer.encode(hasOOLPayload: header.hasOOLPayload))
        return data
    }

    /// Decodes a wire message from bytes.
    ///
    /// - Parameter data: Complete wire message bytes
    /// - Returns: Parsed wire message
    /// - Throws: `FPCError` if the message is malformed
    public static func decode(from data: Data) throws -> WireMessage {
        guard data.count >= WireFormat.minimumMessageSize else {
            throw FPCError.invalidMessageFormat
        }

        // Decode header
        let header = try WireHeader.decode(from: data)
        try header.validate()

        // Validate total size
        let expectedSize = WireFormat.headerSize + Int(header.payloadLength) + WireFormat.trailerSize
        guard data.count == expectedSize else {
            throw FPCError.invalidMessageFormat
        }

        // Extract payload
        let payloadStart = WireFormat.headerSize
        let payloadEnd = payloadStart + Int(header.payloadLength)
        let payload = Data(data[payloadStart..<payloadEnd])

        // Decode trailer
        let trailerStart = payloadEnd
        let trailerData = Data(data[trailerStart...])
        let trailer = try WireTrailer.decode(from: trailerData, descriptorCount: Int(header.descriptorCount))
        try trailer.validate(hasOOLPayload: header.hasOOLPayload)

        return WireMessage(header: header, payload: payload, trailer: trailer)
    }

    /// Converts to a BPC Message (without descriptors - caller must attach).
    public func toMessage() -> Message {
        Message(
            id: MessageID(rawValue: header.messageID),
            correlationID: header.correlationID,
            payload: payload,
            descriptors: []
        )
    }
}
