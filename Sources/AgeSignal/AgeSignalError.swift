/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - AgeSignalError

/// Errors that can occur during age signal operations.
public enum AgeSignalError: Error, Sendable {
    /// Not connected to the age signal daemon
    case notConnected

    /// Failed to connect to the daemon
    case connectionFailed(underlying: Error)

    /// Invalid response from the daemon
    case invalidResponse

    /// Protocol error during communication
    case protocolError(String)

    /// Operation timed out
    case timeout

    /// Invalid birthdate provided
    case invalidBirthdate(String)

    /// User not found in the system
    case userNotFound(String)

    /// Storage error (reading/writing birthdate data)
    case storageError(String)

    /// Permission denied for the operation
    case permissionDenied(String)
}

// MARK: - LocalizedError

extension AgeSignalError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the age signal daemon"
        case .connectionFailed(let underlying):
            return "Failed to connect to daemon: \(underlying.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from the age signal daemon"
        case .protocolError(let message):
            return "Protocol error: \(message)"
        case .timeout:
            return "Operation timed out"
        case .invalidBirthdate(let message):
            return "Invalid birthdate: \(message)"
        case .userNotFound(let user):
            return "User not found: \(user)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}

// MARK: - CustomStringConvertible

extension AgeSignalError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown age signal error"
    }
}
