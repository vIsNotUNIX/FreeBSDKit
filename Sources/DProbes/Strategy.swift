/*
 * DProbes - Swift USDT (Userland Statically Defined Tracing) Macros
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Overview
//
// DProbes provides Swift macros for defining DTrace USDT probes with:
// - Zero overhead when not tracing (IS-ENABLED check before arg evaluation)
// - Type-safe probe definitions with compile-time validation
// - Automatic .d file generation and build integration
//
// This module targets FreeBSD 13+ with DTrace USDT support.

// MARK: - Design Goals
//
// 1. ZERO COST WHEN NOT TRACING
//    - Probes expand to: if (enabled) { evaluate_args; fire_probe; }
//    - When not tracing: single branch instruction (~1-5 nanoseconds)
//    - Arguments never evaluated unless someone is actively tracing
//
// 2. TYPE SAFETY
//    - Compile-time validation of argument types
//    - Clear errors for unsupported types
//    - Enforce DTrace constraints (max 10 args, name lengths)
//
// 3. SIMPLE API
//    - Freestanding macros for both definition and invocation
//    - No special syntax at call sites
//    - Looks like normal Swift code
//
// 4. PRODUCTION READY
//    - Probes always compiled in (DTrace philosophy)
//    - Can attach to running production binaries
//    - No recompilation needed to debug

// MARK: - API Design

/*
 * PROVIDER DEFINITION
 * -------------------
 * Use #DTraceProvider to define a provider with its probes:
 *
 *     #DTraceProvider(
 *         name: "myapp",
 *         stability: .evolving,
 *
 *         probes: {
 *             #probe(
 *                 name: "request_start",
 *                 args: (
 *                     path: String,
 *                     method: Int32,
 *                     requestID: UInt64
 *                 ),
 *                 docs: "Fires when HTTP request processing begins."
 *             )
 *
 *             #probe(
 *                 name: "request_done",
 *                 args: (
 *                     path: String,
 *                     status: Int32,
 *                     latencyNs: UInt64,
 *                     requestID: UInt64
 *                 )
 *             )
 *         }
 *     )
 *
 * PROBE INVOCATION
 * ----------------
 * Use #probe to fire a probe:
 *
 *     #probe(myapp.request_start,
 *         path: request.url.path,
 *         method: request.method.rawValue,
 *         requestID: reqID
 *     )
 *
 * This expands to:
 *
 *     if __dtraceenabled_myapp___request__start() {
 *         let _path = request.url.path
 *         let _method = request.method.rawValue
 *         let _requestID = reqID
 *         _path.withCString { p0 in
 *             __dtrace_myapp___request__start(
 *                 UInt(bitPattern: p0),
 *                 UInt(bitPattern: _method),
 *                 UInt(bitPattern: _requestID)
 *             )
 *         }
 *     }
 */

// MARK: - Supported Types

/// Protocol for types that can be passed as DTrace probe arguments.
///
/// DTrace USDT probes accept arguments as `uintptr_t` values. This protocol
/// defines how Swift types are converted to that representation.
///
/// Built-in conformances:
/// - Integer types: Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64
/// - Boolean: Converted to Int32 (0 or 1)
/// - String: Passed as pointer via withCString
/// - StaticString: Zero-copy pointer to UTF8 data
/// - Optional<String>: nil becomes NULL pointer
/// - UnsafePointer, UnsafeRawPointer: Direct pointer value
///
/// Custom types can conform by providing a conversion to a supported type.
public protocol DTraceConvertible {
    /// The DTrace-compatible representation of this type.
    associatedtype DTraceRepresentation: DTraceConvertible

    /// Convert this value to its DTrace representation.
    var dtraceValue: DTraceRepresentation { get }
}

// MARK: - Constraints

/// DTrace and CTF constraints that are enforced at compile time.
public enum DTraceConstraints {
    /// Maximum number of arguments per probe.
    /// DTrace USDT probes support at most 10 arguments.
    public static let maxArguments = 10

    /// Maximum length of provider name.
    public static let maxProviderNameLength = 64

    /// Maximum length of probe name.
    public static let maxProbeNameLength = 64

    /// Maximum length of module name.
    public static let maxModuleNameLength = 64
}

// MARK: - Stability Attributes

/// Stability level for DTrace providers and probes.
///
/// These attributes communicate to DTrace consumers how likely
/// the probe interface is to change in future versions.
public enum ProbeStability: String {
    /// Internal implementation detail. May change at any time.
    case `private` = "Private"

    /// Project-internal interface. Stable within the project.
    case project = "Project"

    /// Interface may change between major versions.
    case evolving = "Evolving"

    /// Committed interface. Changes are backward compatible.
    case stable = "Stable"

    /// Industry standard interface.
    case standard = "Standard"
}

// MARK: - Performance Characteristics

/*
 * OVERHEAD WHEN NOT TRACING
 * -------------------------
 * Each #probe invocation compiles to an IS-ENABLED check:
 *
 *     if __dtraceenabled_xxx() { ... }
 *
 * This is a single branch instruction that:
 * - Checks a memory location (the probe's enabled flag)
 * - Branch prediction makes this essentially free (~1-5 ns)
 * - Arguments are NEVER evaluated if probe is disabled
 *
 * OVERHEAD WHEN TRACING
 * ---------------------
 * When DTrace is attached and the probe is enabled:
 * - Arguments are evaluated
 * - String arguments are copied to C strings (stack-local)
 * - Probe fires via breakpoint trap to kernel (~600 ns)
 *
 * This overhead only occurs while actively debugging.
 * Detaching DTrace returns to near-zero overhead.
 *
 * COMPARISON
 * ----------
 * | Scenario                    | Cost        |
 * |-----------------------------|-------------|
 * | Probe disabled              | ~1-5 ns     |
 * | Probe enabled (integers)    | ~600 ns     |
 * | Probe enabled (strings)     | ~600 ns + copy |
 * | No probe (compiled out)     | 0 ns        |
 *
 * The difference between "disabled" and "compiled out" is negligible
 * for all practical purposes, but having probes compiled in allows
 * attaching DTrace to production systems without recompilation.
 */

// MARK: - Build Integration

/*
 * SPM BUILD PLUGIN
 * ----------------
 * The DProbes package includes a build plugin that:
 *
 * 1. Scans for #DTraceProvider macro expansions
 * 2. Generates provider.d files from the definitions
 * 3. Runs: dtrace -h -s provider.d -o provider.h
 * 4. Runs: dtrace -G -s provider.d -o provider.o
 * 5. Links provider.o into the final binary
 *
 * This happens automatically during `swift build`.
 *
 * GENERATED FILES
 * ---------------
 * For a provider named "myapp":
 *
 * - myapp_provider.d    : DTrace provider definition
 * - myapp_provider.h    : C header with probe macros
 * - myapp_provider.o    : Object file with probe metadata
 */

// MARK: - Error Diagnostics

/*
 * COMPILE-TIME ERRORS
 * -------------------
 * The macros provide clear diagnostics for common mistakes:
 *
 * #probe(myapp.request, data: someData)
 * // error: 'Data' is not a valid DTrace argument type
 * //        Supported: Int8-64, UInt8-64, String, Bool, UnsafePointer
 *
 * #probe(myapp.request, a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8, i:9, j:10, k:11)
 * // error: DTrace probes support maximum 10 arguments (found 11)
 *
 * #DTraceProvider(name: "this_name_is_way_too_long_for_dtrace", ...)
 * // error: Provider name exceeds 64 character limit
 *
 * #probe(undefined.probe, arg: 1)
 * // error: Unknown provider 'undefined'. Available: myapp, otherapp
 *
 * #probe(myapp.request, wrongArg: 1)
 * // error: Probe 'myapp.request' has no argument 'wrongArg'
 * //        Expected: path, method, requestID
 */
