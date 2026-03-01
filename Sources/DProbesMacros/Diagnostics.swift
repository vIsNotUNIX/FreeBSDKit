/*
 * DProbes Diagnostics - Compile-time Error Messages
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import SwiftDiagnostics

/// Diagnostic errors for DProbes macros
enum DProbesDiagnostic: Error, CustomStringConvertible {
    case missingArguments
    case missingProviderName
    case missingProbeName
    case missingProbeArguments
    case providerNameTooLong(String)
    case probeNameTooLong(String)
    case tooManyArguments(String, Int)
    case probeArgMissingName
    case unsupportedType(String, String)
    case unknownProvider(String)
    case unknownProbe(String, String)
    case argumentMismatch(String, expected: [String], got: [String])

    var description: String {
        switch self {
        case .missingArguments:
            return "DTraceProvider requires arguments"
        case .missingProviderName:
            return "DTraceProvider requires 'name' argument"
        case .missingProbeName:
            return "#probe requires 'name' argument"
        case .missingProbeArguments:
            return "#probe requires arguments"
        case .providerNameTooLong(let name):
            return "Provider name '\(name)' exceeds 64 character limit (\(name.count) characters)"
        case .probeNameTooLong(let name):
            return "Probe name '\(name)' exceeds 64 character limit (\(name.count) characters)"
        case .tooManyArguments(let probe, let count):
            return "Probe '\(probe)' has \(count) arguments, but DTrace supports maximum 10"
        case .probeArgMissingName:
            return "Probe arguments must be labeled (e.g., 'path: String')"
        case .unsupportedType(let probe, let type):
            return "Type '\(type)' is not supported in probe '\(probe)'. Supported types: Int8-64, UInt8-64, String, Bool, UnsafePointer"
        case .unknownProvider(let name):
            return "Unknown provider '\(name)'. Define it using #DTraceProvider first."
        case .unknownProbe(let provider, let probe):
            return "Unknown probe '\(probe)' in provider '\(provider)'"
        case .argumentMismatch(let probe, let expected, let got):
            return "Probe '\(probe)' expects arguments (\(expected.joined(separator: ", "))) but got (\(got.joined(separator: ", ")))"
        }
    }
}

/// Message for diagnostics
struct DProbesMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ error: DProbesDiagnostic, severity: DiagnosticSeverity = .error) {
        self.message = error.description
        self.diagnosticID = MessageID(domain: "DProbes", id: String(describing: error))
        self.severity = severity
    }
}
