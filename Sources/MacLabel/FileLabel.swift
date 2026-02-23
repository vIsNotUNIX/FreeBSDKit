/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - FileLabel

/// Represents a single file and its associated security labels.
///
/// A `FileLabel` is the default implementation of `Labelable` for filesystem-based
/// security labels. It specifies which security attributes (key-value pairs) should be
/// applied to a specific file via FreeBSD extended attributes in the MAC framework namespace.
///
/// ## Example
/// ```swift
/// let label = FileLabel(
///     path: "/bin/sh",
///     attributes: [
///         "type": "shell",
///         "trust": "system",
///         "network": "deny"
///     ]
/// )
/// ```
public struct FileLabel: Labelable {
    /// Absolute path to the file to be labeled
    public let path: String

    /// Security attributes as key-value pairs.
    ///
    /// **Key constraints**:
    /// - Must not be empty
    /// - Must not contain `=`, newlines, or null bytes
    ///
    /// **Value constraints**:
    /// - May contain `=` (parsed with maxSplits: 1)
    /// - Must not contain newlines or null bytes
    /// - May be empty (empty values are allowed)
    public let attributes: [String: String]

    /// Validates that the path exists on the filesystem.
    ///
    /// This validation is a critical safety check to ensure that labels are only
    /// applied to files that actually exist, preventing partial policy application.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if the file does not exist
    /// - Throws: ``LabelError/invalidConfiguration`` if the path is invalid
    public func validatePath() throws {
        // Path should not be empty
        guard !path.isEmpty else {
            throw LabelError.invalidConfiguration("File path cannot be empty")
        }

        // Path should not contain null bytes
        guard !path.contains("\0") else {
            throw LabelError.invalidConfiguration("File path '\(path)' contains null bytes")
        }

        // Check if file exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw LabelError.fileNotFound(path)
        }
    }

    // Uses default encodeAttributes() implementation from Labelable protocol
}
