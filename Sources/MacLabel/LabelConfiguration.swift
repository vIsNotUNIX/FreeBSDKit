/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc


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

    /// Loads a configuration from a JSON file using a file descriptor.
    ///
    /// Uses file descriptors to prevent TOCTOU (Time-of-Check, Time-of-Use)
    /// vulnerabilities. The file is opened, validated with fstat(), and read
    /// all through the same descriptor.
    ///
    /// - Parameter path: Path to the JSON configuration file
    /// - Returns: Decoded configuration
    /// - Throws: Error if file cannot be read or JSON is invalid
    public static func load(from path: String) throws -> LabelConfiguration<Label> {
        // Validate path
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid configuration file path")
        }

        // Open file descriptor with O_RDONLY | O_CLOEXEC
        let fd = path.withCString { cPath in
            open(cPath, O_RDONLY | O_CLOEXEC)
        }

        guard fd >= 0 else {
            throw LabelError.invalidConfiguration("Cannot open configuration file: \(String(cString: strerror(errno)))")
        }

        defer { close(fd) }

        // Use fstat on the descriptor to check file properties
        var st = stat()
        guard fstat(fd, &st) == 0 else {
            throw LabelError.invalidConfiguration("Cannot stat configuration file: \(String(cString: strerror(errno)))")
        }

        // Validate it's a regular file
        guard (st.st_mode & S_IFMT) == S_IFREG else {
            throw LabelError.invalidConfiguration("Configuration path is not a regular file")
        }

        // Check size limit (10MB should be more than enough for any reasonable config)
        guard st.st_size <= 10_485_760 else {
            throw LabelError.invalidConfiguration("Configuration file exceeds maximum size of 10MB")
        }

        guard st.st_size > 0 else {
            throw LabelError.invalidConfiguration("Configuration file is empty")
        }

        // Read file via descriptor
        var buffer = [UInt8](repeating: 0, count: Int(st.st_size))
        let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr in
            read(fd, ptr.baseAddress, Int(st.st_size))
        }

        guard bytesRead == st.st_size else {
            throw LabelError.invalidConfiguration("Failed to read complete configuration file")
        }

        let data = Data(buffer)
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

/// Type alias for FileLabel-based configuration (most common use case).
public typealias FileLabelConfiguration = LabelConfiguration<FileLabel>
