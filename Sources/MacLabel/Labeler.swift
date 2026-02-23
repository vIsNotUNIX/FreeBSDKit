/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import FreeBSDKit
import Capabilities
import Capsicum
import Glibc

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

    /// Validates that all resources in the configuration exist.
    ///
    /// This is a critical safety check. If any resource is missing, the entire
    /// operation must fail to prevent partial policy application.
    ///
    /// - Throws: ``LabelError/fileNotFound`` for the first missing resource
    public func validatePaths() throws {
        for label in configuration.labels {
            try label.validate()
        }
    }

    /// Information about a path including symlink resolution and pattern expansion.
    public struct PathInfo {
        /// The original path from the configuration
        public let path: String
        /// If this path is a symlink, the immediate target
        public let symlinkTarget: String?
        /// The fully resolved path (all symlinks followed)
        public let resolvedPath: String?
        /// Whether this path is a symbolic link
        public var isSymlink: Bool { symlinkTarget != nil }
        /// Whether this path is a recursive pattern (ends with /*)
        public let isRecursivePattern: Bool
        /// For recursive patterns, the expanded file paths
        public let expandedPaths: [String]?

        public init(
            path: String,
            symlinkTarget: String? = nil,
            resolvedPath: String? = nil,
            isRecursivePattern: Bool = false,
            expandedPaths: [String]? = nil
        ) {
            self.path = path
            self.symlinkTarget = symlinkTarget
            self.resolvedPath = resolvedPath
            self.isRecursivePattern = isRecursivePattern
            self.expandedPaths = expandedPaths
        }
    }

    /// Validates both resource paths and attribute formatting.
    ///
    /// This performs comprehensive validation of the entire configuration:
    /// 1. Checks that all resources exist and are accessible
    /// 2. Validates all attribute keys and values are properly formatted
    /// 3. Ensures no forbidden characters in keys or values
    ///
    /// Call this before any operation to catch configuration errors early.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if any resource doesn't exist
    /// - Throws: ``LabelError/invalidAttribute`` if attribute format is invalid
    public func validateConfiguration() throws {
        // First validate all paths exist
        try validatePaths()

        // Then validate all attributes are properly formatted
        for label in configuration.labels {
            try label.validateAttributes()
        }
    }

    /// Applies all labels from the configuration.
    ///
    /// **Safety**: All paths and attributes are validated before applying any labels.
    /// If validation fails, no labels are modified.
    ///
    /// - Returns: Array of results for each file
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    /// - Throws: ``LabelError/invalidAttribute`` if attribute format is invalid
    public func apply() throws -> [LabelingResult] {
        // SAFETY: Validate ALL paths and attributes before applying ANY labels
        if verbose {
            print("Validating configuration...")
        }
        try validateConfiguration()

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
    /// Path is already validated by validateConfiguration() before this is called.
    ///
    /// - Parameter label: Label to apply
    /// - Returns: Result of the operation
    private func applyTo(_ label: Label) -> LabelingResult {
        return applyToCapsicum(label)
    }

    /// Applies a label using path-based operations (traditional method).
    private func applyToPath(_ label: Label) -> LabelingResult {
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

    /// Applies a label using Capsicum-restricted file capabilities.
    ///
    /// Opens the file with minimal rights for defense-in-depth:
    /// - .read, .write, .fstat, .extattr_get, .extattr_set
    ///
    /// Provides TOCTOU protection and kernel-enforced restrictions.
    private func applyToCapsicum(_ label: Label) -> LabelingResult {
        do {
            // Open file with O_RDWR for reading and writing extended attributes
            let rawFd = label.path.withCString { cPath in
                open(cPath, O_RDWR | O_CLOEXEC)
            }

            guard rawFd >= 0 else {
                throw LabelError.extAttrSetFailed(path: label.path, errno: errno)
            }

            // Wrap in FileCapability
            let capability = FileCapability(rawFd)

            // Restrict to minimal rights needed
            let rights = CapsicumRightSet(rights: [
                .read,          // Read for getting existing labels
                .write,         // Write for setting labels
                .fstat,         // Metadata access
                .extattrGet,    // Get extended attributes
                .extattrSet     // Set extended attributes
            ])

            _ = capability.limit(rights: rights)

            // Check for existing label using descriptor
            let previousLabel = try ExtendedAttributes.get(
                descriptor: capability,
                namespace: .system,
                name: configuration.attributeName
            )

            // Don't overwrite if flag is set and label exists
            if !overwriteExisting && previousLabel != nil {
                if verbose {
                    print("  Skipping (label exists and overwrite=false)")
                }
                capability.close()
                return LabelingResult(
                    path: label.path,
                    success: true,
                    error: nil,
                    previousLabel: previousLabel
                )
            }

            // Encode attributes
            let data = try label.encodeAttributes()

            // Set extended attribute using descriptor
            try ExtendedAttributes.set(
                descriptor: capability,
                namespace: .system,
                name: configuration.attributeName,
                data: data
            )

            capability.close()

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
            print("Validating paths...")
        }
        try validatePaths()

        var results: [LabelingResult] = []

        for label in configuration.labels {
            if verbose {
                print("Removing label from: \(label.path)")
            }

            let result = removeLabelFrom(label)
            results.append(result)

            if verbose {
                if result.success {
                    print("  ✓ Successfully removed")
                } else {
                    print("  ✗ Failed: \(result.error?.localizedDescription ?? "unknown error")")
                }
            }
        }

        return results
    }

    /// Removes a label from a single resource.
    private func removeLabelFrom(_ label: Label) -> LabelingResult {
        return removeLabelCapsicum(label)
    }

    /// Removes a label using path-based operations.
    private func removeLabelPath(_ label: Label) -> LabelingResult {
        do {
            try ExtendedAttributes.delete(
                path: label.path,
                namespace: .system,
                name: configuration.attributeName
            )

            return LabelingResult(
                path: label.path,
                success: true,
                error: nil,
                previousLabel: nil
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

    /// Removes a label using Capsicum-restricted file capabilities.
    private func removeLabelCapsicum(_ label: Label) -> LabelingResult {
        do {
            // Open file with O_RDWR for deleting extended attributes
            let rawFd = label.path.withCString { cPath in
                open(cPath, O_RDWR | O_CLOEXEC)
            }

            guard rawFd >= 0 else {
                throw LabelError.extAttrDeleteFailed(path: label.path, errno: errno)
            }

            // Wrap in FileCapability
            let capability = FileCapability(rawFd)

            // Restrict to minimal rights needed for deleting attributes
            let rights = CapsicumRightSet(rights: [
                .write,           // Write for modifying attributes
                .fstat,           // Metadata access
                .extattrDelete    // Delete extended attributes
            ])

            _ = capability.limit(rights: rights)

            // Delete extended attribute using descriptor
            try ExtendedAttributes.delete(
                descriptor: capability,
                namespace: .system,
                name: configuration.attributeName
            )

            capability.close()

            return LabelingResult(
                path: label.path,
                success: true,
                error: nil,
                previousLabel: nil
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

    /// Displays current labels for all files in the configuration.
    ///
    /// **Safety**: All paths are validated before showing any labels.
    ///
    /// - Returns: Array of results with current labels
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func show() throws -> [(path: String, labels: String?)] {
        // SAFETY: Validate ALL paths first
        if verbose {
            print("Validating paths...")
        }
        try validatePaths()

        var results: [(String, String?)] = []

        for label in configuration.labels {
            let labelData = getLabelsFrom(label)
            results.append(labelData)
        }

        return results
    }

    /// Gets labels from a single resource.
    private func getLabelsFrom(_ label: Label) -> (path: String, labels: String?) {
        return getLabelsCapsicum(label)
    }

    /// Gets labels using path-based operations.
    private func getLabelsPath(_ label: Label) -> (path: String, labels: String?) {
        do {
            if let data = try ExtendedAttributes.get(
                path: label.path,
                namespace: .system,
                name: configuration.attributeName
            ) {
                let labelString = String(data: data, encoding: .utf8)
                return (label.path, labelString)
            } else {
                return (label.path, nil)
            }
        } catch {
            return (label.path, "ERROR: \(error.localizedDescription)")
        }
    }

    /// Gets labels using Capsicum-restricted file capabilities.
    private func getLabelsCapsicum(_ label: Label) -> (path: String, labels: String?) {
        do {
            // Open file with O_RDONLY for reading extended attributes
            let rawFd = label.path.withCString { cPath in
                open(cPath, O_RDONLY | O_CLOEXEC)
            }

            guard rawFd >= 0 else {
                return (label.path, "ERROR: Cannot open file: \(String(cString: strerror(errno)))")
            }

            // Wrap in FileCapability
            let capability = FileCapability(rawFd)

            // Restrict to minimal rights needed for reading attributes
            let rights = CapsicumRightSet(rights: [
                .read,          // Read access
                .fstat,         // Metadata access
                .extattrGet     // Get extended attributes
            ])

            _ = capability.limit(rights: rights)

            // Get extended attribute using descriptor
            let data = try ExtendedAttributes.get(
                descriptor: capability,
                namespace: .system,
                name: configuration.attributeName
            )

            capability.close()

            if let data = data {
                let labelString = String(data: data, encoding: .utf8)
                return (label.path, labelString)
            } else {
                return (label.path, nil)
            }
        } catch {
            return (label.path, "ERROR: \(error.localizedDescription)")
        }
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
            print("Validating paths...")
        }
        try validatePaths()

        var results: [VerificationResult] = []

        for label in configuration.labels {
            if verbose {
                print("Verifying: \(label.path)")
            }

            let result = verifyLabel(label)
            results.append(result)

            if verbose {
                if result.matches {
                    print("  ✓ Labels match")
                } else if result.error != nil {
                    print("  ✗ Error: \(result.error!.localizedDescription)")
                } else {
                    print("  ✗ Labels mismatch:")
                    for mismatch in result.mismatches {
                        print("    - \(mismatch)")
                    }
                }
            }
        }

        return results
    }

    /// Verifies a single label.
    private func verifyLabel(_ label: Label) -> VerificationResult {
        return verifyLabelCapsicum(label)
    }

    /// Verifies a label using path-based operations.
    private func verifyLabelPath(_ label: Label) -> VerificationResult {
        do {
            // Get current labels
            guard let data = try ExtendedAttributes.get(
                path: label.path,
                namespace: .system,
                name: configuration.attributeName
            ) else {
                return VerificationResult(
                    path: label.path,
                    matches: false,
                    expected: label.attributes,
                    actual: nil,
                    error: nil,
                    mismatches: ["No labels found"]
                )
            }

            // Parse actual labels
            let actual = try parse(from: data)

            // Compare expected vs actual
            let (matches, mismatches) = compareAttributes(
                expected: label.attributes,
                actual: actual
            )

            return VerificationResult(
                path: label.path,
                matches: matches,
                expected: label.attributes,
                actual: actual,
                error: nil,
                mismatches: mismatches
            )
        } catch {
            return VerificationResult(
                path: label.path,
                matches: false,
                expected: label.attributes,
                actual: nil,
                error: error,
                mismatches: ["Error reading labels: \(error.localizedDescription)"]
            )
        }
    }

    /// Verifies a label using Capsicum-restricted file capabilities.
    private func verifyLabelCapsicum(_ label: Label) -> VerificationResult {
        do {
            // Open file with O_RDONLY for reading extended attributes
            let rawFd = label.path.withCString { cPath in
                open(cPath, O_RDONLY | O_CLOEXEC)
            }

            guard rawFd >= 0 else {
                let error = LabelError.extAttrGetFailed(path: label.path, errno: errno)
                return VerificationResult(
                    path: label.path,
                    matches: false,
                    expected: label.attributes,
                    actual: nil,
                    error: error,
                    mismatches: ["Error opening file: \(error.localizedDescription)"]
                )
            }

            // Wrap in FileCapability
            let capability = FileCapability(rawFd)

            // Restrict to minimal rights needed for reading attributes
            let rights = CapsicumRightSet(rights: [
                .read,          // Read access
                .fstat,         // Metadata access
                .extattrGet     // Get extended attributes
            ])

            _ = capability.limit(rights: rights)

            // Get current labels using descriptor
            guard let data = try ExtendedAttributes.get(
                descriptor: capability,
                namespace: .system,
                name: configuration.attributeName
            ) else {
                capability.close()
                return VerificationResult(
                    path: label.path,
                    matches: false,
                    expected: label.attributes,
                    actual: nil,
                    error: nil,
                    mismatches: ["No labels found"]
                )
            }

            // Parse actual labels
            let actual = try parse(from: data)

            // Compare expected vs actual
            let (matches, mismatches) = compareAttributes(
                expected: label.attributes,
                actual: actual
            )

            capability.close()

            return VerificationResult(
                path: label.path,
                matches: matches,
                expected: label.attributes,
                actual: actual,
                error: nil,
                mismatches: mismatches
            )
        } catch {
            return VerificationResult(
                path: label.path,
                matches: false,
                expected: label.attributes,
                actual: nil,
                error: error,
                mismatches: ["Error reading labels: \(error.localizedDescription)"]
            )
        }
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

// MARK: - FileLabel-specific Extensions

extension Labeler where Label == FileLabel {
    /// Returns path information for all files in the configuration.
    ///
    /// This includes symlink detection, resolution, and pattern expansion,
    /// helping users understand which files will actually be labeled.
    ///
    /// - Returns: Array of path information including symlink targets and pattern expansion
    public func pathInfo() -> [PathInfo] {
        return configuration.labels.map { label in
            if label.isRecursivePattern {
                let expanded = try? label.expandedPaths()
                return PathInfo(
                    path: label.path,
                    symlinkTarget: nil,
                    resolvedPath: nil,
                    isRecursivePattern: true,
                    expandedPaths: expanded
                )
            } else {
                return PathInfo(
                    path: label.path,
                    symlinkTarget: label.symlinkTarget(),
                    resolvedPath: label.resolvedPath(),
                    isRecursivePattern: false,
                    expandedPaths: nil
                )
            }
        }
    }

    /// Validates paths and prints symlink/pattern information in verbose mode.
    ///
    /// This combines validation with informative output about symlinks and
    /// recursive patterns, helping users understand which files will be labeled.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if any path doesn't exist
    public func validatePathsVerbose() throws {
        for label in configuration.labels {
            try label.validate()

            if verbose {
                if label.isRecursivePattern {
                    let expanded = try label.expandedPaths()
                    print("  \(label.path) (recursive pattern, \(expanded.count) files)")
                    for file in expanded.prefix(5) {
                        let expandedLabel = FileLabel(path: file, attributes: [:])
                        if let target = expandedLabel.symlinkTarget() {
                            print("    → \(file) → \(target) (symlink)")
                        } else {
                            print("    → \(file)")
                        }
                    }
                    if expanded.count > 5 {
                        print("    ... and \(expanded.count - 5) more files")
                    }
                } else if let target = label.symlinkTarget() {
                    if let resolved = label.resolvedPath(), resolved != target {
                        // Multi-level symlink
                        print("  \(label.path) → \(target) → \(resolved) (symlink)")
                    } else {
                        print("  \(label.path) → \(target) (symlink)")
                    }
                } else {
                    print("  \(label.path)")
                }
            }
        }
    }

    /// Returns all expanded labels, with recursive patterns expanded to individual files.
    ///
    /// This is used internally to process all files that need to be labeled.
    ///
    /// - Returns: Array of FileLabel instances for all files to be labeled
    /// - Throws: ``LabelError`` if pattern expansion fails
    public func expandedLabels() throws -> [FileLabel] {
        var result: [FileLabel] = []
        for label in configuration.labels {
            if label.isRecursivePattern {
                result.append(contentsOf: try label.expandedLabels())
            } else {
                result.append(label)
            }
        }
        return result
    }

    /// Returns the total count of files that will be labeled.
    ///
    /// This includes files from recursive pattern expansion.
    ///
    /// - Returns: Total number of files to be labeled
    public func totalFileCount() -> Int {
        var count = 0
        for label in configuration.labels {
            if label.isRecursivePattern {
                count += (try? label.expandedPaths().count) ?? 0
            } else {
                count += 1
            }
        }
        return count
    }

    /// Applies labels with recursive pattern expansion.
    ///
    /// This method expands any recursive patterns (paths ending with `/*`) to
    /// their individual files before applying labels. Results are returned for
    /// each individual file.
    ///
    /// - Returns: Array of results for each file (including expanded patterns)
    /// - Throws: ``LabelError`` if validation or expansion fails
    public func applyExpanded() throws -> [LabelingResult] {
        // SAFETY: Validate ALL paths and attributes before applying ANY labels
        if verbose {
            print("Validating configuration...")
        }
        try validateConfiguration()

        // Expand all patterns
        let allLabels = try expandedLabels()

        if verbose && allLabels.count != configuration.labels.count {
            print("Expanded to \(allLabels.count) files")
        }

        // Now apply labels to each file
        var results: [LabelingResult] = []

        for label in allLabels {
            if verbose {
                print("Processing: \(label.path)")
            }

            let result = applyToCapsicum(label)
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

    /// Removes labels with recursive pattern expansion.
    ///
    /// - Returns: Array of results for each file
    /// - Throws: ``LabelError`` if validation or expansion fails
    public func removeExpanded() throws -> [LabelingResult] {
        if verbose {
            print("Validating configuration...")
        }
        try validatePaths()

        let allLabels = try expandedLabels()

        if verbose && allLabels.count != configuration.labels.count {
            print("Expanded to \(allLabels.count) files")
        }

        var results: [LabelingResult] = []

        for label in allLabels {
            if verbose {
                print("Removing label from: \(label.path)")
            }

            let result = removeLabelCapsicum(label)
            results.append(result)

            if verbose {
                if result.success {
                    print("  ✓ Successfully removed")
                } else {
                    print("  ✗ Failed: \(result.error?.localizedDescription ?? "unknown error")")
                }
            }
        }

        return results
    }

    /// Shows labels with recursive pattern expansion.
    ///
    /// - Returns: Array of (path, labels) tuples
    /// - Throws: ``LabelError`` if validation or expansion fails
    public func showExpanded() throws -> [(path: String, labels: String?)] {
        if verbose {
            print("Validating configuration...")
        }
        try validatePaths()

        let allLabels = try expandedLabels()

        if verbose && allLabels.count != configuration.labels.count {
            print("Expanded to \(allLabels.count) files")
        }

        var results: [(path: String, labels: String?)] = []

        for label in allLabels {
            let result = getLabelsCapsicum(label)
            results.append(result)
        }

        return results
    }

    /// Verifies labels with recursive pattern expansion.
    ///
    /// - Returns: Array of verification results
    /// - Throws: ``LabelError`` if validation or expansion fails
    public func verifyExpanded() throws -> [VerificationResult] {
        if verbose {
            print("Validating configuration...")
        }
        try validatePaths()

        let allLabels = try expandedLabels()

        if verbose && allLabels.count != configuration.labels.count {
            print("Expanded to \(allLabels.count) files")
        }

        var results: [VerificationResult] = []

        for label in allLabels {
            if verbose {
                print("Verifying: \(label.path)")
            }

            let result = verifyLabelCapsicum(label)
            results.append(result)

            if verbose {
                if result.matches {
                    print("  ✓ Labels match")
                } else if let error = result.error {
                    print("  ✗ Error: \(error.localizedDescription)")
                } else {
                    print("  ✗ Mismatches found")
                }
            }
        }

        return results
    }
}
