/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation


/// Result of a single file labeling operation.
public struct LabelingResult: Sendable {
    /// Path that was processed
    public let path: String

    /// Whether the operation succeeded
    public let success: Bool

    /// Error if operation failed
    public let error: Error?

    /// Previous label data (if any)
    public let previousLabel: Data?
}


/// Result of verifying a single file's labels.
public struct VerificationResult: Sendable {
    /// Path that was verified
    public let path: String

    /// Whether labels match expected configuration
    public let matches: Bool

    /// Expected attributes from configuration
    public let expected: [String: String]

    /// Actual attributes found on file (nil if no labels)
    public let actual: [String: String]?

    /// Error if verification failed
    public let error: Error?

    /// Specific mismatches (missing/extra/different keys)
    public let mismatches: [String]
}
