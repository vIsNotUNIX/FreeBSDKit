/*
 * dprobes-cli - Type Definitions
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - DTrace Constraints

/// DTrace USDT constraints enforced during validation.
enum Constraints {
    /// Maximum arguments per probe (DTrace USDT limit).
    static let maxArguments = 10

    /// Maximum provider name length.
    static let maxProviderNameLength = 64

    /// Maximum probe name length.
    static let maxProbeNameLength = 64

    /// Valid Swift argument types that map to C types.
    static let validTypes: Set<String> = [
        "Int8", "Int16", "Int32", "Int64", "Int",
        "UInt8", "UInt16", "UInt32", "UInt64", "UInt",
        "Bool", "String"
    ]

    /// Valid DTrace stability levels.
    static let validStabilities: Set<String> = [
        "Private", "Project", "Evolving", "Stable", "Standard"
    ]

    /// Swift keywords that cannot be used as argument names.
    static let swiftKeywords: Set<String> = [
        // Declaration keywords
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var",
        // Statement keywords
        "break", "case", "catch", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch",
        "throw", "throws", "try", "where", "while",
        // Expression keywords
        "Any", "as", "false", "is", "nil", "self", "Self", "super", "true", "_"
    ]
}

// MARK: - Probe Definition Models

/// A single probe argument.
struct ProbeArgument: Codable {
    let name: String
    let type: String
}

/// A probe definition with name, optional arguments, and documentation.
struct ProbeDefinition: Codable {
    let name: String
    let args: [ProbeArgument]?
    let docs: String?
}

/// A complete provider definition containing multiple probes.
struct ProviderDefinition: Codable {
    let name: String
    let stability: String?
    let probes: [ProbeDefinition]
}
