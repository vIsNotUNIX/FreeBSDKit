/*
 * DTraceProviderMacro - Provider Definition Macro
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// A freestanding declaration macro that defines a DTrace provider with probes.
///
/// Usage:
/// ```swift
/// #DTraceProvider(
///     name: "myapp",
///     stability: .evolving,
///     probes: {
///         #probe(name: "request_start", args: (path: String, method: Int32))
///         #probe(name: "request_done", args: (path: String, status: Int32))
///     }
/// )
/// ```
public struct DTraceProviderMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Parse the provider definition from arguments
        guard let arguments = node.arguments else {
            throw DProbesDiagnostic.missingArguments
        }

        // Extract provider name
        guard let nameArg = arguments.first(labeled: "name"),
              let nameExpr = nameArg.expression.as(StringLiteralExprSyntax.self),
              let providerName = nameExpr.representedLiteralValue else {
            throw DProbesDiagnostic.missingProviderName
        }

        // Validate provider name length
        if providerName.count > 64 {
            throw DProbesDiagnostic.providerNameTooLong(providerName)
        }

        // Extract stability (optional, defaults to .evolving)
        var stability = "Evolving"
        if let stabilityArg = arguments.first(labeled: "stability"),
           let memberAccess = stabilityArg.expression.as(MemberAccessExprSyntax.self) {
            stability = memberAccess.declName.baseName.text.capitalized
        }

        // Extract probe definitions from the trailing closure
        var probeDefinitions: [ProbeDefinition] = []

        if let probesArg = arguments.first(labeled: "probes"),
           let closure = probesArg.expression.as(ClosureExprSyntax.self) {
            probeDefinitions = try parseProbesFromClosure(closure, context: context)
        }

        // Generate the output declarations
        var declarations: [DeclSyntax] = []

        // 1. Generate the provider enum/namespace
        let providerEnum = generateProviderEnum(
            name: providerName,
            stability: stability,
            probes: probeDefinitions
        )
        declarations.append(providerEnum)

        // 2. Generate the C function declarations for each probe
        for probe in probeDefinitions {
            let externDecl = generateExternDeclaration(provider: providerName, probe: probe)
            declarations.append(externDecl)
        }

        return declarations
    }

    /// Parse probe definitions from the trailing closure
    private static func parseProbesFromClosure(
        _ closure: ClosureExprSyntax,
        context: some MacroExpansionContext
    ) throws -> [ProbeDefinition] {
        var probes: [ProbeDefinition] = []

        for statement in closure.statements {
            // Look for #probe(...) macro calls
            if let exprStmt = statement.item.as(ExpressionStmtSyntax.self),
               let macroExpr = exprStmt.expression.as(MacroExpansionExprSyntax.self),
               macroExpr.macroName.text == "probe" {

                let probe = try parseProbeDefinition(macroExpr)
                probes.append(probe)
            }
        }

        return probes
    }

    /// Parse a single #probe definition
    private static func parseProbeDefinition(
        _ macro: MacroExpansionExprSyntax
    ) throws -> ProbeDefinition {
        guard let arguments = macro.arguments else {
            throw DProbesDiagnostic.missingProbeArguments
        }

        // Extract probe name
        guard let nameArg = arguments.first(labeled: "name"),
              let nameExpr = nameArg.expression.as(StringLiteralExprSyntax.self),
              let probeName = nameExpr.representedLiteralValue else {
            throw DProbesDiagnostic.missingProbeName
        }

        // Validate probe name length
        if probeName.count > 64 {
            throw DProbesDiagnostic.probeNameTooLong(probeName)
        }

        // Extract argument types from args: (name: Type, ...)
        var probeArgs: [(name: String, type: String)] = []

        if let argsArg = arguments.first(labeled: "args"),
           let tuple = argsArg.expression.as(TupleExprSyntax.self) {

            for element in tuple.elements {
                guard let label = element.label?.text else {
                    throw DProbesDiagnostic.probeArgMissingName
                }

                // Get the type from the expression
                let typeString = element.expression.description.trimmingCharacters(in: .whitespaces)
                probeArgs.append((name: label, type: typeString))
            }
        }

        // Validate argument count
        if probeArgs.count > 10 {
            throw DProbesDiagnostic.tooManyArguments(probeName, probeArgs.count)
        }

        // Extract documentation (optional)
        var docs: String? = nil
        if let docsArg = arguments.first(labeled: "docs"),
           let docsExpr = docsArg.expression.as(StringLiteralExprSyntax.self) {
            docs = docsExpr.representedLiteralValue
        }

        return ProbeDefinition(
            name: probeName,
            arguments: probeArgs,
            documentation: docs
        )
    }

    /// Generate the provider enum with probe functions
    private static func generateProviderEnum(
        name: String,
        stability: String,
        probes: [ProbeDefinition]
    ) -> DeclSyntax {
        let sanitizedName = sanitizeIdentifier(name)

        var memberDecls: [String] = []

        for probe in probes {
            let funcDecl = generateProbeFunction(provider: name, probe: probe)
            memberDecls.append(funcDecl)
        }

        let membersJoined = memberDecls.joined(separator: "\n\n    ")

        return """
        /// DTrace provider: \(raw: name)
        /// Stability: \(raw: stability)
        public enum \(raw: sanitizedName) {
            \(raw: membersJoined)
        }
        """
    }

    /// Generate a probe firing function
    private static func generateProbeFunction(
        provider: String,
        probe: ProbeDefinition
    ) -> String {
        let funcName = sanitizeIdentifier(probe.name)
        let enabledFuncName = "_\(provider)_\(probe.name.replacingOccurrences(of: "_", with: "__"))_enabled"
        let probeFuncName = "__dtrace_\(provider)___\(probe.name.replacingOccurrences(of: "_", with: "__"))"

        // Build parameter list
        var params: [String] = []
        var argEvals: [String] = []
        var probeArgs: [String] = []
        var stringBindings: [(name: String, ptrName: String)] = []

        for (index, arg) in probe.arguments.enumerated() {
            let paramName = arg.name
            let paramType = arg.type

            // Parameter in function signature - using @autoclosure for lazy evaluation
            params.append("\(paramName): @autoclosure () -> \(paramType)")

            // Evaluate argument
            argEvals.append("let _\(paramName) = \(paramName)()")

            // Handle type conversion
            if paramType == "String" {
                let ptrName = "_p\(index)"
                stringBindings.append((name: "_\(paramName)", ptrName: ptrName))
                probeArgs.append("UInt(bitPattern: \(ptrName))")
            } else {
                probeArgs.append("UInt(bitPattern: _\(paramName))")
            }
        }

        let paramsJoined = params.joined(separator: ", ")
        let argEvalsJoined = argEvals.joined(separator: "\n            ")
        let probeArgsJoined = probeArgs.joined(separator: ", ")

        // Build the function body with string bindings
        var body: String
        if stringBindings.isEmpty {
            // No strings, simple case
            body = """
            guard \(enabledFuncName)() else { return }
                    \(argEvalsJoined)
                    \(probeFuncName)(\(probeArgsJoined))
            """
        } else {
            // Has strings, need withCString nesting
            body = """
            guard \(enabledFuncName)() else { return }
                    \(argEvalsJoined)
            """

            // Build nested withCString calls
            var indent = "        "
            for binding in stringBindings {
                body += "\n\(indent)\(binding.name).withCString { \(binding.ptrName) in"
                indent += "    "
            }

            body += "\n\(indent)\(probeFuncName)(\(probeArgsJoined))"

            // Close the withCString blocks
            for _ in stringBindings {
                indent = String(indent.dropLast(4))
                body += "\n\(indent)}"
            }
        }

        // Documentation
        var docComment = ""
        if let docs = probe.documentation {
            docComment = "/// \(docs)\n    "
        }

        return """
        \(docComment)@inlinable
            public static func \(funcName)(\(paramsJoined)) {
                \(body)
            }
        """
    }

    /// Generate extern declaration for C probe function
    private static func generateExternDeclaration(
        provider: String,
        probe: ProbeDefinition
    ) -> DeclSyntax {
        let enabledFuncName = "_\(provider)_\(probe.name.replacingOccurrences(of: "_", with: "__"))_enabled"
        let probeFuncName = "__dtrace_\(provider)___\(probe.name.replacingOccurrences(of: "_", with: "__"))"

        // Generate UInt parameters for each argument
        let argCount = probe.arguments.count
        let uintParams = (0..<argCount).map { "_ arg\($0): UInt" }.joined(separator: ", ")

        return """
        @_silgen_name("\(raw: enabledFuncName)")
        @usableFromInline
        func \(raw: enabledFuncName)() -> Bool

        @_silgen_name("\(raw: probeFuncName)")
        @usableFromInline
        func \(raw: probeFuncName)(\(raw: uintParams))
        """
    }

    /// Sanitize a string to be a valid Swift identifier
    private static func sanitizeIdentifier(_ name: String) -> String {
        var result = name
        // Replace hyphens and other invalid chars with underscores
        result = result.replacingOccurrences(of: "-", with: "_")
        result = result.replacingOccurrences(of: ".", with: "_")
        // Capitalize first letter for type names
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        return result
    }
}

/// Represents a parsed probe definition
struct ProbeDefinition {
    let name: String
    let arguments: [(name: String, type: String)]
    let documentation: String?
}

/// Helper extension to find labeled arguments
extension LabeledExprListSyntax {
    func first(labeled label: String) -> LabeledExprSyntax? {
        first { $0.label?.text == label }
    }
}
