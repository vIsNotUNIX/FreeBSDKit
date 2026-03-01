/*
 * DProbes - Swift USDT Probes for FreeBSD
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Module Info

/// DProbes provides Swift USDT probe support for FreeBSD.
///
/// ## Overview
///
/// DProbes allows Swift developers to instrument their applications with
/// statically defined tracing probes that can be observed using DTrace.
/// The probes have zero overhead when not being traced.
///
/// ## Quick Start
///
/// 1. Define probes in a `.dprobes` file (JSON format):
///
/// ```json
/// {
///   "name": "myapp",
///   "stability": "Evolving",
///   "probes": [
///     {
///       "name": "request",
///       "args": [
///         { "name": "path", "type": "String" },
///         { "name": "status", "type": "Int32" }
///       ]
///     }
///   ]
/// }
/// ```
///
/// 2. Generate Swift code:
///
/// ```bash
/// swift run dprobes-gen myapp.dprobes --output-dir .
/// ```
///
/// 3. Use probes in your code:
///
/// ```swift
/// Myapp.request(path: "/api/users", status: 200)
/// ```
///
/// 4. Trace with DTrace:
///
/// ```bash
/// sudo dtrace -n 'myapp:::request { printf("%s: %d\n", copyinstr(arg0), arg1); }'
/// ```
///
/// ## Features
///
/// - Zero overhead when not tracing (IS-ENABLED check before arg evaluation)
/// - Code generation from YAML probe definitions
/// - Support for Int8-64, UInt8-64, String, Bool, and pointers
/// - Custom type translation via `DTraceConvertible` protocol
///
/// ## Requirements
///
/// - FreeBSD 13+ with DTrace USDT support
/// - Swift 5.9+
///
/// ## Implementation Note
///
/// Swift macros require SPM macro target support, which is not yet available
/// in FreeBSD's Swift Package Manager. DProbes uses code generation instead:
///
/// 1. Define probes in a `.dprobes` file (YAML format)
/// 2. Run: `swift run dprobes-gen <input.dprobes> --output-dir <dir>`
/// 3. The generator creates Swift code with IS-ENABLED checks
/// 4. For full DTrace support: `dtrace -h -s provider.d && dtrace -G -s provider.d`
/// 5. Link the `provider.o` file with your binary
///
/// When SPM macro support becomes available on FreeBSD, we may add
/// `#DTraceProvider` and `#probe` macros for compile-time validation.
///
/// - SeeAlso: ``DTraceConvertible``
/// - SeeAlso: ``DTraceConstraints``
/// - SeeAlso: ``ProbeStability``
public enum DProbes {
    /// Current version of the DProbes module.
    public static let version = "0.1.0"
}

// MARK: - Module Exports

// Strategy.swift exports:
// - DTraceConvertible (protocol)
// - DTraceConstraints (enum)
// - ProbeStability (enum)

// Testing.swift exports:
// - ProbeRecorder (class)
// - DTraceTestHelpers (enum)
// - DTraceTestError (enum)
// - ProbeAssertions (enum)
// - MockClock (struct)
