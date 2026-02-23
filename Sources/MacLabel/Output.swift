/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation


/// JSON-serializable result for a single labeling operation (apply or remove).
public struct OperationResult: Codable, Sendable {
    public let path: String
    public let success: Bool
    public let error: String?
    public let previousLabel: String?

    public init(from result: LabelingResult) {
        self.path = result.path
        self.success = result.success
        self.error = result.error?.localizedDescription
        self.previousLabel = result.previousLabel.flatMap {
            String(data: $0, encoding: .utf8)
        }
    }
}

/// JSON-serializable result for a single verification operation.
public struct VerificationResultJSON: Codable, Sendable {
    public let path: String
    public let matches: Bool
    public let expected: [String: String]
    public let actual: [String: String]?
    public let error: String?
    public let mismatches: [String]

    public init(from result: VerificationResult) {
        self.path = result.path
        self.matches = result.matches
        self.expected = result.expected
        self.actual = result.actual
        self.error = result.error?.localizedDescription
        self.mismatches = result.mismatches
    }
}

/// Summary of apply or remove operations with statistics.
public struct OperationSummary: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let successfulFiles: Int
    public let failedFiles: Int
    public let results: [OperationResult]

    public init(results: [LabelingResult]) {
        self.results = results.map { OperationResult(from: $0) }
        self.totalFiles = results.count
        self.successfulFiles = results.filter { $0.success }.count
        self.failedFiles = results.filter { !$0.success }.count
        self.success = failedFiles == 0
    }
}

/// Summary of verification operations with statistics.
public struct VerificationSummary: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let matchingFiles: Int
    public let mismatchedFiles: Int
    public let results: [VerificationResultJSON]

    public init(results: [VerificationResult]) {
        self.results = results.map { VerificationResultJSON(from: $0) }
        self.totalFiles = results.count
        self.matchingFiles = results.filter { $0.matches }.count
        self.mismatchedFiles = results.filter { !$0.matches }.count
        self.success = mismatchedFiles == 0
    }
}

/// Summary of show operation displaying current labels.
public struct LabelsSummary: Codable, Sendable {
    public struct FileLabels: Codable, Sendable {
        public let path: String
        public let labels: [String: String]?
        public let error: String?

        public init(path: String, labelsString: String?) {
            self.path = path

            if let labelsString = labelsString {
                if labelsString.hasPrefix("ERROR:") {
                    self.labels = nil
                    self.error = labelsString
                } else {
                    // Parse labels string
                    var parsedLabels: [String: String] = [:]
                    for line in labelsString.split(separator: "\n") {
                        let parts = line.split(separator: "=", maxSplits: 1)
                        if parts.count == 2 {
                            parsedLabels[String(parts[0])] = String(parts[1])
                        }
                    }
                    self.labels = parsedLabels.isEmpty ? nil : parsedLabels
                    self.error = nil
                }
            } else {
                self.labels = nil
                self.error = nil
            }
        }
    }

    public let files: [FileLabels]

    public init(results: [(path: String, labels: String?)]) {
        self.files = results.map { FileLabels(path: $0.path, labelsString: $0.labels) }
    }
}

/// Information about a symlink in the configuration.
public struct SymlinkInfo: Codable, Sendable {
    /// The path specified in the configuration
    public let path: String
    /// The resolved target path
    public let target: String

    public init(path: String, target: String) {
        self.path = path
        self.target = target
    }
}

/// Summary of configuration validation.
public struct ValidationSummary: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let attributeName: String
    public let error: String?
    /// Symlinks detected in the configuration (labels will be applied to targets)
    public let symlinks: [SymlinkInfo]?

    public init(success: Bool, totalFiles: Int, attributeName: String, error: String? = nil, symlinks: [SymlinkInfo]? = nil) {
        self.success = success
        self.totalFiles = totalFiles
        self.attributeName = attributeName
        self.error = error
        self.symlinks = symlinks?.isEmpty == true ? nil : symlinks
    }
}

/// Outputs a JSON-encoded value to stdout.
///
/// Uses pretty-printed, sorted output for consistent formatting.
public func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let string = String(data: data, encoding: .utf8) {
        print(string)
    }
}
