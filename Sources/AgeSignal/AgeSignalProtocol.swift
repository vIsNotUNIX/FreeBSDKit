/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import FPC

// MARK: - Message IDs

/// FPC Message IDs for the age signal protocol.
///
/// These are in the user-defined range (256+) to avoid conflicts with
/// the system-reserved message IDs.
public extension MessageID {
    // Requests (256-259)

    /// Query the caller's own age bracket (no payload)
    static let ageQueryOwn = MessageID(rawValue: 256)

    /// Query a specific user's age bracket (payload: 4 bytes UID, requires privilege)
    static let ageQueryUser = MessageID(rawValue: 257)

    /// Set a user's birthdate (payload: 4 bytes UID + 2 bytes birthdate, requires root)
    static let ageSetBirthdate = MessageID(rawValue: 258)

    /// Remove a user's birthdate (payload: 4 bytes UID, requires root)
    static let ageRemove = MessageID(rawValue: 259)

    // Responses (260-261)

    /// Response containing status and bracket
    static let ageResponse = MessageID(rawValue: 260)

    /// Error response with message
    static let ageError = MessageID(rawValue: 261)
}

// MARK: - AgeSignalRequest

/// A request in the age signal protocol.
///
/// This enum represents the different operations that can be performed via the
/// aged daemon's FPC protocol. Each case corresponds to a specific ``MessageID``
/// and payload format.
///
/// Used internally by ``AgeSignalClient`` and the aged daemon for wire protocol
/// encoding/decoding. Most applications should use ``AgeSignalClient`` directly
/// rather than constructing requests manually.
public enum AgeSignalRequest: Sendable {
    /// Query the caller's own age bracket
    case queryOwn

    /// Query a specific user's age bracket (privileged)
    case queryUser(uid: UInt32)

    /// Set a user's birthdate (privileged)
    case setBirthdate(uid: UInt32, birthdate: Birthdate)

    /// Remove a user's birthdate (privileged)
    case remove(uid: UInt32)

    /// Encodes the request to FPCMessage payload.
    public func toMessage() -> FPCMessage {
        switch self {
        case .queryOwn:
            return FPCMessage(id: .ageQueryOwn)

        case .queryUser(let uid):
            var payload = Data(count: 4)
            payload[0] = UInt8((uid >> 24) & 0xFF)
            payload[1] = UInt8((uid >> 16) & 0xFF)
            payload[2] = UInt8((uid >> 8) & 0xFF)
            payload[3] = UInt8(uid & 0xFF)
            return FPCMessage(id: .ageQueryUser, payload: payload)

        case .setBirthdate(let uid, let birthdate):
            var payload = Data(count: 6)
            payload[0] = UInt8((uid >> 24) & 0xFF)
            payload[1] = UInt8((uid >> 16) & 0xFF)
            payload[2] = UInt8((uid >> 8) & 0xFF)
            payload[3] = UInt8(uid & 0xFF)
            let bdData = birthdate.serialize()
            payload[4] = bdData[0]
            payload[5] = bdData[1]
            return FPCMessage(id: .ageSetBirthdate, payload: payload)

        case .remove(let uid):
            var payload = Data(count: 4)
            payload[0] = UInt8((uid >> 24) & 0xFF)
            payload[1] = UInt8((uid >> 16) & 0xFF)
            payload[2] = UInt8((uid >> 8) & 0xFF)
            payload[3] = UInt8(uid & 0xFF)
            return FPCMessage(id: .ageRemove, payload: payload)
        }
    }

    /// Decodes a request from an FPCMessage.
    public static func from(message: FPCMessage) throws -> AgeSignalRequest {
        switch message.id {
        case .ageQueryOwn:
            return .queryOwn

        case .ageQueryUser:
            guard message.payload.count >= 4 else {
                throw AgeSignalError.protocolError("ageQueryUser requires 4 byte UID payload")
            }
            let uid = decodeUID(from: message.payload)
            return .queryUser(uid: uid)

        case .ageSetBirthdate:
            guard message.payload.count >= 6 else {
                throw AgeSignalError.protocolError("ageSetBirthdate requires 6 byte payload (UID + birthdate)")
            }
            let uid = decodeUID(from: message.payload)
            let bdData = Data([message.payload[4], message.payload[5]])
            let birthdate = try Birthdate(deserializing: bdData)
            return .setBirthdate(uid: uid, birthdate: birthdate)

        case .ageRemove:
            guard message.payload.count >= 4 else {
                throw AgeSignalError.protocolError("ageRemove requires 4 byte UID payload")
            }
            let uid = decodeUID(from: message.payload)
            return .remove(uid: uid)

        default:
            throw AgeSignalError.protocolError("Unknown message ID: \(message.id)")
        }
    }

    private static func decodeUID(from data: Data) -> UInt32 {
        UInt32(data[0]) << 24 |
        UInt32(data[1]) << 16 |
        UInt32(data[2]) << 8 |
        UInt32(data[3])
    }
}

// MARK: - AgeSignalResponse

/// A response in the age signal protocol.
///
/// The response is 2 bytes: status (1 byte) + bracket (1 byte)
public struct AgeSignalResponse: Sendable {
    public let status: AgeSignalStatus
    public let bracket: AgeBracket?

    public init(status: AgeSignalStatus, bracket: AgeBracket? = nil) {
        self.status = status
        self.bracket = bracket
    }

    /// Creates a successful response with a bracket.
    public static func success(_ bracket: AgeBracket) -> AgeSignalResponse {
        AgeSignalResponse(status: .ok, bracket: bracket)
    }

    /// Creates an error response.
    public static func error(_ status: AgeSignalStatus) -> AgeSignalResponse {
        AgeSignalResponse(status: status, bracket: nil)
    }

    /// Encodes the response to a 2-byte payload.
    public func encode() -> Data {
        Data([status.rawValue, bracket?.rawValue ?? 0xFF])
    }

    /// Creates an FPCMessage reply.
    public func toMessage(replyingTo original: FPCMessage) -> FPCMessage {
        FPCMessage.reply(to: original, id: .ageResponse, payload: encode())
    }

    /// Decodes a response from a 2-byte payload.
    public static func decode(from data: Data) throws -> AgeSignalResponse {
        guard data.count >= 2 else {
            throw AgeSignalError.protocolError("Response requires at least 2 bytes")
        }

        guard let status = AgeSignalStatus(rawValue: data[0]) else {
            throw AgeSignalError.protocolError("Invalid status code: \(data[0])")
        }

        // Bracket is optional - 0xFF means no bracket (used for remove operations)
        let bracket = AgeBracket(rawValue: data[1])

        return AgeSignalResponse(status: status, bracket: bracket)
    }

    /// Converts the response to an AgeSignalResult.
    public func toResult() -> AgeSignalResult {
        switch status {
        case .ok:
            // For query operations, bracket should be present
            // For remove operations, bracket may be nil (success without bracket)
            if let bracket = bracket {
                return .bracket(bracket)
            }
            // ok with no bracket means operation succeeded (e.g., remove)
            return .notSet
        case .notSet:
            return .notSet
        case .permissionDenied:
            return .permissionDenied
        case .unknownUser:
            return .unknownUser
        case .invalidRequest:
            return .error(AgeSignalError.protocolError("Invalid request"))
        case .serviceUnavailable:
            return .error(AgeSignalError.protocolError("Service unavailable"))
        }
    }
}

// MARK: - Protocol Constants

/// Constants for the age signal protocol.
public enum AgeSignalProtocol {
    /// Default socket path for the aged daemon
    public static let defaultSocketPath = "/var/run/aged.sock"

    /// Database directory for birthdate storage
    public static let databasePath = "/var/db/aged"

    /// Extended attribute name for birthdate storage
    public static let birthdateAttribute = "birthdate"
}
