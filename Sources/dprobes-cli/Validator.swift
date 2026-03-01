/*
 * dprobes-cli - Validation
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// Validates provider definitions against DTrace constraints.
enum Validator {

    /// Validate a provider definition.
    ///
    /// - Parameter provider: The provider to validate
    /// - Throws: GeneratorError.validationFailed on constraint violations
    static func validate(_ provider: ProviderDefinition) throws {
        try validateProviderName(provider.name)
        try validateStability(provider.stability)
        try validateProbes(provider.probes)
    }

    private static func validateProviderName(_ name: String) throws {
        try validateIdentifier(name, kind: "Provider")
    }

    private static func validateStability(_ stability: String?) throws {
        guard let stability = stability else { return }
        if !Constraints.validStabilities.contains(stability) {
            throw GeneratorError.validationFailed(
                "Invalid stability '\(stability)'. " +
                "Must be one of: \(Constraints.validStabilities.sorted().joined(separator: ", "))"
            )
        }
    }

    private static func validateProbes(_ probes: [ProbeDefinition]) throws {
        var seenNames = Set<String>()
        for probe in probes {
            if seenNames.contains(probe.name) {
                throw GeneratorError.validationFailed(
                    "Duplicate probe name '\(probe.name)'"
                )
            }
            seenNames.insert(probe.name)
            try validateProbe(probe)
        }
    }

    private static func validateProbe(_ probe: ProbeDefinition) throws {
        try validateIdentifier(probe.name, kind: "Probe")

        let args = probe.args ?? []
        if args.count > Constraints.maxArguments {
            throw GeneratorError.validationFailed(
                "Probe '\(probe.name)' has \(args.count) arguments (maximum is \(Constraints.maxArguments))"
            )
        }

        try validateArguments(args, probeName: probe.name)
    }

    private static func validateArguments(_ args: [ProbeArgument], probeName: String) throws {
        var seenNames = Set<String>()
        for arg in args {
            if arg.name.isEmpty {
                throw GeneratorError.validationFailed(
                    "Probe '\(probeName)' has argument with empty name"
                )
            }

            if seenNames.contains(arg.name) {
                throw GeneratorError.validationFailed(
                    "Probe '\(probeName)' has duplicate argument name '\(arg.name)'"
                )
            }
            seenNames.insert(arg.name)

            if Constraints.swiftKeywords.contains(arg.name) {
                throw GeneratorError.validationFailed(
                    "Probe '\(probeName)' argument '\(arg.name)' is a Swift keyword"
                )
            }

            if !Constraints.validTypes.contains(arg.type) {
                throw GeneratorError.validationFailed(
                    "Probe '\(probeName)' argument '\(arg.name)' has unsupported type '\(arg.type)'. " +
                    "Supported: \(Constraints.validTypes.sorted().joined(separator: ", "))"
                )
            }
        }
    }

    private static func validateIdentifier(_ name: String, kind: String) throws {
        if name.isEmpty {
            throw GeneratorError.validationFailed("\(kind) name cannot be empty")
        }

        let maxLength = kind == "Provider"
            ? Constraints.maxProviderNameLength
            : Constraints.maxProbeNameLength

        if name.count > maxLength {
            throw GeneratorError.validationFailed(
                "\(kind) name '\(name)' exceeds \(maxLength) character limit"
            )
        }

        let first = name.first!
        if !first.isLetter && first != "_" {
            throw GeneratorError.validationFailed(
                "\(kind) name '\(name)' must start with a letter or underscore"
            )
        }

        if name.contains(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) {
            throw GeneratorError.validationFailed(
                "\(kind) name '\(name)' contains invalid characters (use letters, numbers, underscore)"
            )
        }
    }
}
