/*
 * ProbeMacro - Probe Invocation Expression Macro
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import SwiftSyntax
import SwiftSyntaxMacros

/// A freestanding expression macro that fires a DTrace probe.
///
/// Usage:
/// ```swift
/// #probe(myapp.request_start, path: req.path, method: 1)
/// ```
///
/// Expands to:
/// ```swift
/// Myapp.request_start(path: req.path, method: 1)
/// ```
///
/// The generated function includes IS-ENABLED check and lazy argument evaluation.
public struct ProbeMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let arguments = node.arguments,
              let firstArg = arguments.first else {
            throw DProbesDiagnostic.missingArguments
        }

        // Parse provider.probe_name from the first argument
        let probeRef = firstArg.expression.description.trimmingCharacters(in: .whitespaces)

        // Split into provider and probe name
        let parts = probeRef.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else {
            throw DProbesDiagnostic.missingProbeName
        }

        let providerName = String(parts[0])
        let probeName = String(parts[1])

        // Convert to Swift identifiers
        let providerIdent = sanitizeIdentifier(providerName)
        let probeIdent = sanitizeIdentifier(probeName)

        // Build the remaining arguments (the probe arguments)
        var probeArgs: [String] = []
        for arg in arguments.dropFirst() {
            if let label = arg.label {
                probeArgs.append("\(label.text): \(arg.expression)")
            } else {
                probeArgs.append("\(arg.expression)")
            }
        }

        let argsString = probeArgs.joined(separator: ", ")

        // Generate the call to the provider's probe function
        if argsString.isEmpty {
            return "\(raw: providerIdent).\(raw: probeIdent)()"
        } else {
            return "\(raw: providerIdent).\(raw: probeIdent)(\(raw: argsString))"
        }
    }

    /// Sanitize a string to be a valid Swift identifier
    private static func sanitizeIdentifier(_ name: String) -> String {
        var result = name
        result = result.replacingOccurrences(of: "-", with: "_")
        result = result.replacingOccurrences(of: ".", with: "_")
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        return result
    }
}

/// A freestanding expression macro that checks if a probe is enabled.
///
/// Usage:
/// ```swift
/// if #probeEnabled(myapp.debug) {
///     let expensive = computeExpensiveData()
///     #probe(myapp.debug, data: expensive)
/// }
/// ```
public struct ProbeEnabledMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let arguments = node.arguments,
              let firstArg = arguments.first else {
            throw DProbesDiagnostic.missingArguments
        }

        // Parse provider.probe_name
        let probeRef = firstArg.expression.description.trimmingCharacters(in: .whitespaces)

        let parts = probeRef.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else {
            throw DProbesDiagnostic.missingProbeName
        }

        let providerName = String(parts[0])
        let probeName = String(parts[1])

        // Generate the enabled check function name
        let enabledFuncName = "_\(providerName)_\(probeName.replacingOccurrences(of: "_", with: "__"))_enabled"

        return "\(raw: enabledFuncName)()"
    }
}
