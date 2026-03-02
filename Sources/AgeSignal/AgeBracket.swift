/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - AgeBracket

/// Age bracket as defined by California AB-1043.
///
/// The bill requires operating systems to provide age signals in four brackets:
/// - Under 13 years old
/// - 13-15 years old
/// - 16-17 years old
/// - 18 years or older (adult)
///
/// This enum uses a single byte for minimal data transmission, as required by the bill.
public enum AgeBracket: UInt8, Sendable, Codable, CaseIterable {
    /// Under 13 years old
    case under13 = 0x00

    /// 13-15 years old
    case age13to15 = 0x01

    /// 16-17 years old
    case age16to17 = 0x02

    /// 18 years or older
    case adult = 0x03
}

// MARK: - CustomStringConvertible

extension AgeBracket: CustomStringConvertible {
    public var description: String {
        switch self {
        case .under13:
            return "under13"
        case .age13to15:
            return "13-15"
        case .age16to17:
            return "16-17"
        case .adult:
            return "18+"
        }
    }

    /// A human-readable description of the age bracket.
    public var humanReadable: String {
        switch self {
        case .under13:
            return "Under 13 years old"
        case .age13to15:
            return "13 to 15 years old"
        case .age16to17:
            return "16 to 17 years old"
        case .adult:
            return "18 years or older"
        }
    }
}

// MARK: - AgeSignalStatus

/// Response status from the aged daemon.
public enum AgeSignalStatus: UInt8, Sendable {
    /// Success - the bracket field is valid
    case ok = 0x00

    /// User hasn't set their birthdate
    case notSet = 0x01

    /// Not authorized to query that UID
    case permissionDenied = 0x02

    /// UID doesn't exist in the system
    case unknownUser = 0x03

    /// Malformed request
    case invalidRequest = 0x04

    /// Internal daemon error
    case serviceUnavailable = 0x05
}

extension AgeSignalStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ok:
            return "ok"
        case .notSet:
            return "not_set"
        case .permissionDenied:
            return "permission_denied"
        case .unknownUser:
            return "unknown_user"
        case .invalidRequest:
            return "invalid_request"
        case .serviceUnavailable:
            return "service_unavailable"
        }
    }
}

// MARK: - AgeSignalResult

/// Result of an age signal query.
public enum AgeSignalResult: Sendable, Equatable {
    /// Successfully retrieved the age bracket
    case bracket(AgeBracket)

    /// User hasn't set their birthdate yet
    case notSet

    /// Not authorized to query that user's bracket
    case permissionDenied

    /// The specified user doesn't exist
    case unknownUser

    /// An error occurred
    case error(AgeSignalError)

    public static func == (lhs: AgeSignalResult, rhs: AgeSignalResult) -> Bool {
        switch (lhs, rhs) {
        case (.bracket(let a), .bracket(let b)):
            return a == b
        case (.notSet, .notSet):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case (.unknownUser, .unknownUser):
            return true
        case (.error(let a), .error(let b)):
            return a.localizedDescription == b.localizedDescription
        default:
            return false
        }
    }
}

extension AgeSignalResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bracket(let bracket):
            return "bracket(\(bracket))"
        case .notSet:
            return "notSet"
        case .permissionDenied:
            return "permissionDenied"
        case .unknownUser:
            return "unknownUser"
        case .error(let error):
            return "error(\(error))"
        }
    }
}
