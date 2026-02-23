/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - Labelable Protocol

/// A protocol for any resource that can be labeled with security attributes.
///
/// Conforming types can represent files, network endpoints, database objects,
/// or any other resource that needs to be tagged with key-value security attributes.
///
/// ## Example Implementation
/// ```swift
/// struct NetworkEndpointLabel: Labelable {
///     let path: String  // URL or endpoint identifier
///     let attributes: [String: String]
///
///     func validatePath() throws {
///         guard URL(string: path) != nil else {
///             throw LabelError.invalidConfiguration("Invalid URL")
///         }
///     }
///
///     func encodeAttributes() throws -> Data {
///         // Custom encoding for network labels
///     }
/// }
/// ```
public protocol Labelable: Codable {
    /// Path or identifier for the resource to label.
    ///
    /// For file-based labels, this is an absolute filesystem path.
    /// For other resource types, this could be a URL, database key, etc.
    var path: String { get }

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
    var attributes: [String: String] { get }

    /// Validates that the resource path/identifier is valid.
    ///
    /// Implementations should verify that the resource exists and is accessible.
    /// For file-based labels, this checks if the file exists on the filesystem.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if resource doesn't exist
    /// - Throws: ``LabelError/invalidConfiguration`` if path is invalid
    func validatePath() throws

    /// Encodes attributes to the wire format for storage.
    ///
    /// The default implementation uses newline-separated key=value pairs:
    /// `key1=value1\nkey2=value2\n`
    ///
    /// Implementations can override this to use custom encoding formats.
    ///
    /// - Returns: UTF-8 encoded attribute data
    /// - Throws: ``LabelError/invalidAttribute`` if keys/values contain forbidden characters
    /// - Throws: ``LabelError/encodingFailed`` if encoding fails
    func encodeAttributes() throws -> Data
}

// MARK: - Default Implementation

public extension Labelable {
    /// Default implementation that encodes attributes as newline-separated key=value pairs.
    ///
    /// This format is designed to be easily parseable by C code and is sorted
    /// alphabetically by key for consistent output.
    ///
    /// Format: `key1=value1\nkey2=value2\n`
    func encodeAttributes() throws -> Data {
        var result = ""

        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            // Validate key is not empty
            guard !key.isEmpty else {
                throw LabelError.invalidAttribute("Attribute key cannot be empty")
            }

            // Validate no forbidden characters in key
            guard !key.contains("=") && !key.contains("\n") && !key.contains("\0") else {
                throw LabelError.invalidAttribute(
                    "Key '\(key)' contains forbidden character (=, newline, or null)"
                )
            }

            // Validate no forbidden characters in value
            guard !value.contains("\n") && !value.contains("\0") else {
                throw LabelError.invalidAttribute(
                    "Value for key '\(key)' contains forbidden character (newline or null)"
                )
            }

            result += "\(key)=\(value)\n"
        }

        guard let data = result.data(using: .utf8) else {
            throw LabelError.encodingFailed
        }

        return data
    }
}
