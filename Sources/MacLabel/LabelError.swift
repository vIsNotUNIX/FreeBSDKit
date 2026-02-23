/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - LabelError

/// Errors that can occur during labeling operations.
public enum LabelError: Error {
    /// The specified file was not found at the given path
    case fileNotFound(String)

    /// Invalid attribute key or value in label configuration or file data
    case invalidAttribute(String)

    /// Failed to encode attributes to UTF-8
    case encodingFailed

    /// Failed to set extended attribute on file
    case extAttrSetFailed(path: String, errno: Int32)

    /// Failed to get extended attribute from file
    case extAttrGetFailed(path: String, errno: Int32)

    /// Failed to delete extended attribute from file
    case extAttrDeleteFailed(path: String, errno: Int32)

    /// Failed to list extended attributes on file
    case extAttrListFailed(path: String, errno: Int32)

    /// Configuration file is invalid or malformed
    case invalidConfiguration(String)
}

extension LabelError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidAttribute(let message):
            return "Invalid attribute: \(message)"
        case .encodingFailed:
            return "Failed to encode attributes to UTF-8"
        case .extAttrSetFailed(let path, let errno):
            return "Failed to set extended attribute on \(path): \(Self.formatErrno(errno))"
        case .extAttrGetFailed(let path, let errno):
            return "Failed to get extended attribute on \(path): \(Self.formatErrno(errno))"
        case .extAttrDeleteFailed(let path, let errno):
            return "Failed to delete extended attribute on \(path): \(Self.formatErrno(errno))"
        case .extAttrListFailed(let path, let errno):
            return "Failed to list extended attributes on \(path): \(Self.formatErrno(errno))"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }

    private static func formatErrno(_ errno: Int32) -> String {
        if let cStr = strerror(errno) {
            let errStr = String(cString: cStr)
            return "\(errStr) (errno=\(errno))"
        }
        return "errno=\(errno)"
    }
}

// Provide localized descriptions for better error reporting
extension LabelError: Sendable, LocalizedError {
    public var errorDescription: String? {
        description
    }
}
