/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

/// Errors that can occur during extended attribute operations.
public enum ExtAttrError: Error, Sendable {
    /// Invalid path provided for extended attribute operation.
    case invalidPath(String)

    /// Invalid attribute name provided.
    case invalidAttributeName(String)

    /// Failed to set extended attribute.
    case setFailed(path: String, namespace: String, name: String, errno: Int32)

    /// Failed to get extended attribute.
    case getFailed(path: String, namespace: String, name: String, errno: Int32)

    /// Failed to delete extended attribute.
    case deleteFailed(path: String, namespace: String, name: String, errno: Int32)

    /// Failed to list extended attributes.
    case listFailed(path: String, namespace: String, errno: Int32)

    /// Attribute value too large to read.
    case valueTooLarge(path: String, size: Int)

    /// Invalid file descriptor.
    case invalidFileDescriptor(String)
}

extension ExtAttrError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidPath(let message):
            return "Invalid path: \(message)"
        case .invalidAttributeName(let message):
            return "Invalid attribute name: \(message)"
        case .setFailed(let path, let namespace, let name, let errno):
            return "Failed to set extended attribute '\(namespace).\(name)' on \(path): errno \(errno)"
        case .getFailed(let path, let namespace, let name, let errno):
            return "Failed to get extended attribute '\(namespace).\(name)' from \(path): errno \(errno)"
        case .deleteFailed(let path, let namespace, let name, let errno):
            return "Failed to delete extended attribute '\(namespace).\(name)' from \(path): errno \(errno)"
        case .listFailed(let path, let namespace, let errno):
            return "Failed to list extended attributes in '\(namespace)' on \(path): errno \(errno)"
        case .valueTooLarge(let path, let size):
            return "Extended attribute value too large on \(path): \(size) bytes"
        case .invalidFileDescriptor(let message):
            return "Invalid file descriptor: \(message)"
        }
    }
}

extension ExtAttrError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
