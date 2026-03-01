/*
 * dprobes-cli - JSON Parser
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

/// Parses .dprobes JSON files into ProviderDefinition.
enum Parser {

    /// Parse JSON content into a provider definition.
    ///
    /// - Parameter content: JSON string from .dprobes file
    /// - Returns: Parsed provider definition
    /// - Throws: GeneratorError on parse failure
    static func parse(_ content: String) throws -> ProviderDefinition {
        guard let data = content.data(using: .utf8) else {
            throw GeneratorError.invalidInput("Invalid UTF-8 content")
        }

        let decoder = JSONDecoder()
        do {
            let provider = try decoder.decode(ProviderDefinition.self, from: data)
            guard !provider.name.isEmpty else {
                throw GeneratorError.missingProviderName
            }
            return provider
        } catch let error as DecodingError {
            throw GeneratorError.invalidInput(decodeErrorMessage(error))
        }
    }

    private static func decodeErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required key: \(key.stringValue)"
        case .typeMismatch(_, let context):
            return "Type mismatch: \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Invalid JSON: \(context.debugDescription)"
        default:
            return "JSON parsing error: \(error.localizedDescription)"
        }
    }
}
