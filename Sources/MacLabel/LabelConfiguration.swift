/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - LabelConfiguration

/// Configuration file format for labeling resources.
///
/// A generic configuration that works with any type conforming to `Labelable`.
/// The JSON structure defines a list of resources and their associated
/// security labels (key-value pairs).
///
/// ## Example JSON (with FileLabel)
/// ```json
/// {
///   "attributeName": "mac.labels",
///   "labels": [
///     {
///       "path": "/bin/sh",
///       "attributes": {
///         "type": "shell",
///         "trust": "system",
///         "network": "deny"
///       }
///     },
///     {
///       "path": "/usr/bin/curl",
///       "attributes": {
///         "type": "network_client",
///         "trust": "user",
///         "network": "allow"
///       }
///     }
///   ]
/// }
/// ```
public struct LabelConfiguration<Label: Labelable>: Codable {
    /// Name of the extended attribute to use (REQUIRED).
    ///
    /// This allows different MACF policies to use different attribute names.
    /// There is no default value - each policy must explicitly specify its
    /// attribute name to prevent conflicts between different policies.
    ///
    /// Common examples:
    /// - `"mac.labels"` - General purpose security labels
    /// - `"mac.policy1"` - Policy-specific labels
    /// - `"mac.network"` - Network-specific policy labels
    public let attributeName: String

    /// List of labels to apply
    public let labels: [Label]

    /// Loads a configuration from a JSON file.
    ///
    /// - Parameter path: Path to the JSON configuration file
    /// - Returns: Decoded configuration
    /// - Throws: Error if file cannot be read or JSON is invalid
    public static func load(from path: String) throws -> LabelConfiguration<Label> {
        // Validate path
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid configuration file path")
        }

        // Load file with size limit (10MB should be more than enough for any reasonable config)
        let url = URL(fileURLWithPath: path)
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: path)
        if let fileSize = fileAttributes[.size] as? UInt64, fileSize > 10_485_760 {
            throw LabelError.invalidConfiguration("Configuration file exceeds maximum size of 10MB")
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let config = try decoder.decode(LabelConfiguration<Label>.self, from: data)

        // Validate attribute name is safe for extended attributes
        try config.validateAttributeName()

        return config
    }

    /// Validates that the attribute name is safe for use in extended attributes.
    ///
    /// Uses conservative validation to prevent edge cases and parsing ambiguities.
    /// Only allows a safe subset of characters commonly used in policy names.
    ///
    /// - Throws: ``LabelError/invalidConfiguration`` if attribute name is invalid
    private func validateAttributeName() throws {
        // Attribute name should not be empty
        guard !attributeName.isEmpty else {
            throw LabelError.invalidConfiguration("Attribute name cannot be empty")
        }

        // Reject leading/trailing whitespace (likely a mistake)
        let trimmed = attributeName.trimmingCharacters(in: .whitespaces)
        guard trimmed == attributeName else {
            throw LabelError.invalidConfiguration(
                "Attribute name '\(attributeName)' has leading or trailing whitespace"
            )
        }

        // Attribute name should not contain path separators, nulls, whitespace, or control chars
        let invalidChars = CharacterSet(charactersIn: "/\0")
            .union(.newlines)
            .union(.whitespaces)
            .union(.controlCharacters)

        guard attributeName.rangeOfCharacter(from: invalidChars) == nil else {
            throw LabelError.invalidConfiguration(
                "Attribute name '\(attributeName)' contains invalid characters (/, null, whitespace, or control chars)"
            )
        }

        // Conservative character set: only allow alphanumeric, period, underscore, hyphen
        let allowedChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        guard attributeName.rangeOfCharacter(from: allowedChars.inverted) == nil else {
            throw LabelError.invalidConfiguration(
                "Attribute name '\(attributeName)' contains characters outside safe set [A-Za-z0-9._-]"
            )
        }

        // Attribute name should be reasonable length (FreeBSD limit is 255 bytes for extattr names)
        guard attributeName.utf8.count <= 255 else {
            throw LabelError.invalidConfiguration(
                "Attribute name '\(attributeName)' exceeds maximum length of 255 bytes"
            )
        }
    }
}

// MARK: - Type Alias for Backwards Compatibility

/// Type alias for FileLabel-based configuration (most common use case).
public typealias FileLabelConfiguration = LabelConfiguration<FileLabel>
