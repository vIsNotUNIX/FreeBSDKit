/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - Labeler

/// Applies security labels to resources based on configuration.
///
/// A generic labeler that works with any type conforming to `Labelable`.
/// The labeler reads a JSON configuration file, validates all resources exist,
/// and applies the specified labels to extended attributes in the MACF
/// namespace using the configured attribute name.
///
/// **Safety**: All resources are validated before any operations. If even one
/// resource is invalid, the entire operation fails. This prevents partial
/// policy application which could leave the system in an inconsistent state.
public struct Labeler<Label: Labelable> {

    /// Configuration to apply
    private let configuration: LabelConfiguration<Label>

    /// Whether to overwrite existing labels (default: true)
    public var overwriteExisting: Bool = true

    /// Whether to print verbose output
    public var verbose: Bool = false

    /// Creates a labeler with the given configuration.
    ///
    /// - Parameter configuration: Label configuration to apply
    public init(configuration: LabelConfiguration<Label>) {
        self.configuration = configuration
    }

    /// Validates that all paths in the configuration exist.
    ///
    /// This is a critical safety check. If any file is missing, the entire
    /// operation must fail to prevent partial policy application.
    ///
    /// - Throws: ``LabelError/fileNotFound`` for the first missing file
    public func validateAllPaths() throws {
        for label in configuration.labels {
            try label.validatePath()
        }
    }

    /// Applies all labels from the configuration.
    ///
    /// **Safety**: All paths are validated before applying any labels.
    /// If validation fails, no labels are modified.
    ///
    /// - Returns: Array of results for each file
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func apply() throws -> [LabelingResult] {
        // SAFETY: Validate ALL paths before applying ANY labels
        if verbose {
            print("Validating all paths...")
        }
        try validateAllPaths()

        // Now apply labels to each file
        var results: [LabelingResult] = []

        for label in configuration.labels {
            if verbose {
                print("Processing: \(label.path)")
            }

            let result = applyTo(label)
            results.append(result)

            if verbose {
                if result.success {
                    print("  ✓ Successfully labeled")
                } else {
                    print("  ✗ Failed: \(result.error?.localizedDescription ?? "unknown error")")
                }
            }
        }

        return results
    }

    /// Applies a single label to a resource.
    ///
    /// Path is already validated by validateAllPaths() before this is called.
    ///
    /// - Parameter label: Label to apply
    /// - Returns: Result of the operation
    private func applyTo(_ label: Label) -> LabelingResult {
        do {
            // Check for existing label
            let previousLabel = try ExtendedAttributes.get(
                path: label.path,
                namespace: .system,
                name: configuration.attributeName
            )

            // Don't overwrite if flag is set and label exists
            if !overwriteExisting && previousLabel != nil {
                if verbose {
                    print("  Skipping (label exists and overwrite=false)")
                }
                return LabelingResult(
                    path: label.path,
                    success: true,
                    error: nil,
                    previousLabel: previousLabel
                )
            }

            // Encode attributes
            let data = try label.encodeAttributes()

            // Set extended attribute
            try ExtendedAttributes.set(
                path: label.path,
                namespace: .system,
                name: configuration.attributeName,
                data: data
            )

            return LabelingResult(
                path: label.path,
                success: true,
                error: nil,
                previousLabel: previousLabel
            )

        } catch {
            return LabelingResult(
                path: label.path,
                success: false,
                error: error,
                previousLabel: nil
            )
        }
    }

    /// Removes labels from all files in the configuration.
    ///
    /// **Safety**: All paths are validated before removing any labels.
    ///
    /// - Returns: Array of results for each file
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func remove() throws -> [LabelingResult] {
        // SAFETY: Validate ALL paths before removing ANY labels
        if verbose {
            print("Validating all paths...")
        }
        try validateAllPaths()

        var results: [LabelingResult] = []

        for label in configuration.labels {
            if verbose {
                print("Removing label from: \(label.path)")
            }

            do {
                try ExtendedAttributes.delete(
                    path: label.path,
                    namespace: .system,
                    name: configuration.attributeName
                )

                results.append(LabelingResult(
                    path: label.path,
                    success: true,
                    error: nil,
                    previousLabel: nil
                ))

                if verbose {
                    print("  ✓ Successfully removed")
                }

            } catch {
                results.append(LabelingResult(
                    path: label.path,
                    success: false,
                    error: error,
                    previousLabel: nil
                ))

                if verbose {
                    print("  ✗ Failed: \(error.localizedDescription)")
                }
            }
        }

        return results
    }

    /// Displays current labels for all files in the configuration.
    ///
    /// **Safety**: All paths are validated before showing any labels.
    ///
    /// - Returns: Array of results with current labels
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func show() throws -> [(path: String, labels: String?)] {
        // SAFETY: Validate ALL paths first
        if verbose {
            print("Validating all paths...")
        }
        try validateAllPaths()

        var results: [(String, String?)] = []

        for label in configuration.labels {
            do {
                if let data = try ExtendedAttributes.get(
                    path: label.path,
                    namespace: .system,
                    name: configuration.attributeName
                ) {
                    let labelString = String(data: data, encoding: .utf8)
                    results.append((label.path, labelString))
                } else {
                    results.append((label.path, nil))
                }
            } catch {
                results.append((label.path, "ERROR: \(error.localizedDescription)"))
            }
        }

        return results
    }

    /// Verifies that labels are correctly applied to all files in the configuration.
    ///
    /// **Safety**: All paths are validated before verifying any labels.
    ///
    /// Checks that each file has the exact labels specified in the configuration.
    /// Reports mismatches including missing, extra, or incorrect attribute values.
    ///
    /// - Returns: Array of verification results for each file
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func verify() throws -> [VerificationResult] {
        // SAFETY: Validate ALL paths first
        if verbose {
            print("Validating all paths...")
        }
        try validateAllPaths()

        var results: [VerificationResult] = []

        for label in configuration.labels {
            if verbose {
                print("Verifying: \(label.path)")
            }

            do {
                // Get current labels
                guard let data = try ExtendedAttributes.get(
                    path: label.path,
                    namespace: .system,
                    name: configuration.attributeName
                ) else {
                    // No labels on file
                    results.append(VerificationResult(
                        path: label.path,
                        matches: false,
                        expected: label.attributes,
                        actual: nil,
                        error: nil,
                        mismatches: ["No labels found"]
                    ))

                    if verbose {
                        print("  ✗ No labels found")
                    }
                    continue
                }

                // Parse actual labels
                let actual = try parse(from: data)

                // Compare expected vs actual
                let (matches, mismatches) = compareAttributes(
                    expected: label.attributes,
                    actual: actual
                )

                results.append(VerificationResult(
                    path: label.path,
                    matches: matches,
                    expected: label.attributes,
                    actual: actual,
                    error: nil,
                    mismatches: mismatches
                ))

                if verbose {
                    if matches {
                        print("  ✓ Labels match")
                    } else {
                        print("  ✗ Labels mismatch:")
                        for mismatch in mismatches {
                            print("    - \(mismatch)")
                        }
                    }
                }

            } catch {
                results.append(VerificationResult(
                    path: label.path,
                    matches: false,
                    expected: label.attributes,
                    actual: nil,
                    error: error,
                    mismatches: ["Error reading labels: \(error.localizedDescription)"]
                ))

                if verbose {
                    print("  ✗ Error reading labels: \(error.localizedDescription)")
                }
            }
        }

        return results
    }

    /// Parses label data into a dictionary.
    ///
    /// Uses strict parsing to detect corruption or tampering. For a security
    /// labeling tool, malformed labels should be treated as errors.
    ///
    /// - Parameter data: Raw label data from extended attribute
    /// - Returns: Dictionary of key-value pairs
    /// - Throws: ``LabelError`` if parsing fails or data is malformed
    private func parse(from data: Data) throws -> [String: String] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw LabelError.encodingFailed
        }

        var result: [String: String] = [:]
        var lineNumber = 0

        // Split on newlines, but filter out empty lines (trailing newline is ok)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            lineNumber += 1

            // Skip empty lines (including final empty line from trailing \n)
            if line.isEmpty {
                continue
            }

            // Parse key=value format (value can contain =)
            let parts = line.split(separator: "=", maxSplits: 1)

            // Strict mode: malformed line is an error
            guard parts.count == 2 else {
                throw LabelError.invalidAttribute(
                    "Malformed label entry at line \(lineNumber): '\(line)' (missing '=')"
                )
            }

            let key = String(parts[0])
            let value = String(parts[1])

            // Validate key is not empty
            guard !key.isEmpty else {
                throw LabelError.invalidAttribute(
                    "Empty key at line \(lineNumber)"
                )
            }

            // Strict mode: detect duplicate keys (possible corruption or tampering)
            if result[key] != nil {
                throw LabelError.invalidAttribute(
                    "Duplicate key '\(key)' at line \(lineNumber)"
                )
            }

            result[key] = value
        }

        return result
    }

    /// Compares expected and actual attributes.
    ///
    /// - Parameters:
    ///   - expected: Expected attributes from configuration
    ///   - actual: Actual attributes from file
    /// - Returns: Tuple of (matches, mismatches)
    private func compareAttributes(
        expected: [String: String],
        actual: [String: String]
    ) -> (matches: Bool, mismatches: [String]) {
        var mismatches: [String] = []

        // Check for missing keys
        for (key, expectedValue) in expected {
            if let actualValue = actual[key] {
                if actualValue != expectedValue {
                    mismatches.append("Key '\(key)': expected '\(expectedValue)', got '\(actualValue)'")
                }
            } else {
                mismatches.append("Missing key: '\(key)'")
            }
        }

        // Check for extra keys
        for key in actual.keys {
            if expected[key] == nil {
                mismatches.append("Unexpected key: '\(key)'")
            }
        }

        return (mismatches.isEmpty, mismatches)
    }
}

/// Type alias for FileLabel-based labeler (most common use case).
public typealias FileLabeler = Labeler<FileLabel>
