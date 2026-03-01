/*
 * dprobes-cli - Error Types
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// Errors from the dprobes code generator.
enum GeneratorError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case directoryNotFound(String)
    case invalidInput(String)
    case missingProviderName
    case validationFailed(String)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .directoryNotFound(let path):
            return "Output directory not found: \(path)"
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        case .missingProviderName:
            return "Provider definition missing 'name' field"
        case .validationFailed(let msg):
            return "Validation failed: \(msg)"
        }
    }
}
