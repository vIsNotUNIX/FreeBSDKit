/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation


/// Serializable result for labeling operations.
public struct SerializableLabelingResult: Codable, Sendable {
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

/// Serializable result for verification operations.
public struct SerializableVerificationResult: Codable, Sendable {
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

/// Serializable result for apply operation.
public struct ApplyOutput: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let successfulFiles: Int
    public let failedFiles: Int
    public let results: [SerializableLabelingResult]

    public init(results: [LabelingResult]) {
        self.results = results.map { SerializableLabelingResult(from: $0) }
        self.totalFiles = results.count
        self.successfulFiles = results.filter { $0.success }.count
        self.failedFiles = results.filter { !$0.success }.count
        self.success = failedFiles == 0
    }
}

/// Serializable result for verify operation.
public struct VerifyOutput: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let matchingFiles: Int
    public let mismatchedFiles: Int
    public let results: [SerializableVerificationResult]

    public init(results: [VerificationResult]) {
        self.results = results.map { SerializableVerificationResult(from: $0) }
        self.totalFiles = results.count
        self.matchingFiles = results.filter { $0.matches }.count
        self.mismatchedFiles = results.filter { !$0.matches }.count
        self.success = mismatchedFiles == 0
    }
}

/// Serializable result for show operation.
public struct ShowOutput: Codable, Sendable {
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

/// Serializable result for validate operation.
public struct ValidateOutput: Codable, Sendable {
    public let success: Bool
    public let totalFiles: Int
    public let attributeName: String
    public let error: String?

    public init(success: Bool, totalFiles: Int, attributeName: String, error: String? = nil) {
        self.success = success
        self.totalFiles = totalFiles
        self.attributeName = attributeName
        self.error = error
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
