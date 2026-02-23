/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Descriptors


/// Configuration file format for labeling resources.
///
/// A generic configuration that works with any type conforming to `Labelable`.
/// The JSON structure defines a list of resources and their associated
/// security labels (key-value pairs).
///
/// ## Example JSON (with FileLabel)
/// ```json
/// {
///   "attributeName": "mac_policy",
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
    /// **Important**: FreeBSD extended attribute names cannot contain dots (`.`).
    /// Use underscores or hyphens instead.
    ///
    /// Common examples:
    /// - `"mac_labels"` - General purpose security labels
    /// - `"mac_policy1"` - Policy-specific labels
    /// - `"mac_network"` - Network-specific policy labels
    public let attributeName: String

    /// List of labels to apply
    public let labels: [Label]

    /// Loads a configuration from a JSON file using an open file descriptor.
    ///
    /// **TOCTOU Protection**: Accepting a file descriptor instead of a path
    /// prevents time-of-check-time-of-use vulnerabilities. The caller opens
    /// the file once and passes the descriptor, ensuring the validated file
    /// is the one being read.
    ///
    /// **Capsicum Support**: Works with any `Descriptor` type, including
    /// `FileCapability` for privilege-restricted access. When using FileCapability,
    /// the descriptor should be restricted to `.read`, `.fstat`, and `.seek` rights.
    ///
    /// **Ownership**: This method does NOT close the descriptor. The
    /// caller retains ownership and is responsible for closing it.
    ///
    /// **Lifecycle**: This method must be called BEFORE entering Capsicum capability
    /// mode if the file needs to be opened by path. After capability mode, only
    /// file descriptors opened before entering capability mode can be used.
    ///
    /// - Parameter descriptor: Open file descriptor to read from (must be readable)
    /// - Returns: Decoded configuration
    /// - Throws: Error if file cannot be read or JSON is invalid
    public static func load<D: Descriptor & ReadableDescriptor>(from descriptor: borrowing D) throws -> LabelConfiguration<Label> where D: ~Copyable {
        // Get file stats using Descriptor protocol
        let st = try descriptor.stat()

        // Validate it's a regular file
        guard (st.st_mode & S_IFMT) == S_IFREG else {
            throw LabelError.invalidConfiguration("Configuration descriptor is not a regular file")
        }

        // Check size limit (10MB should be more than enough for any reasonable config)
        guard st.st_size <= 10_485_760 else {
            throw LabelError.invalidConfiguration("Configuration file exceeds maximum size of 10MB")
        }

        guard st.st_size > 0 else {
            throw LabelError.invalidConfiguration("Configuration file is empty")
        }

        // Read file using Descriptor's readExact() method
        // This handles EINTR retries and ensures we read the complete file
        let data = try descriptor.readExact(Int(st.st_size))

        let decoder = JSONDecoder()
        let config = try decoder.decode(LabelConfiguration<Label>.self, from: data)

        // Validate attribute name is safe for extended attributes
        try config.validateAttributeName()

        // Validate all label attributes early (fail fast)
        for label in config.labels {
            try label.validateAttributes()
        }

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

        // Conservative character set: only allow alphanumeric, underscore, hyphen
        // NOTE: Dots (.) are NOT allowed - FreeBSD extattr rejects them with EINVAL
        let allowedChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        guard attributeName.rangeOfCharacter(from: allowedChars.inverted) == nil else {
            throw LabelError.invalidConfiguration(
                "Attribute name '\(attributeName)' contains invalid characters (only A-Za-z0-9_- allowed; dots are not permitted)"
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
