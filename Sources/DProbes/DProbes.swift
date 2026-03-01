/*
 * DProbes - Swift USDT Probes for FreeBSD
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// DProbes provides Swift USDT (Userland Statically Defined Tracing) probe
/// support for FreeBSD.
///
/// ## Overview
///
/// USDT probes allow instrumenting applications with tracing points that can be
/// observed using DTrace. Probes have near-zero overhead (~2-5ns) when not traced.
///
/// ## Quick Start
///
/// ### 1. Define probes in JSON (.dprobes file):
///
/// ```json
/// {
///   "name": "myapp",
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
/// ### 2. Generate code:
///
/// ```bash
/// swift run dprobes-gen myapp.dprobes --output-dir .
/// ```
///
/// ### 3. Use probes:
///
/// ```swift
/// Myapp.request(path: "/api/users", status: 200)
/// ```
///
/// ### 4. Build:
///
/// ```bash
/// swiftc -c *.swift -module-name MyApp
/// dtrace -G -s myapp_provider.d *.o -o myapp_provider.o
/// swiftc *.o myapp_provider.o -o myapp
/// ```
///
/// ### 5. Trace:
///
/// ```bash
/// # Provider name includes PID at runtime (myapp1234), use wildcard
/// sudo dtrace -n 'myapp*:::* { printf("%s\n", probename); }' -Z -c ./myapp
/// ```
///
/// ## Supported Types
///
/// | Swift      | C Type    | DTrace Access     |
/// |------------|-----------|-------------------|
/// | Int8-64    | int*_t    | arg0              |
/// | UInt8-64   | uint*_t   | arg0              |
/// | Bool       | int32_t   | arg0              |
/// | String     | char *    | copyinstr(arg0)   |
///
/// ## Probe Metadata
///
/// DTrace probes have four components: `provider:module:function:name`
///
/// - **provider**: Defined in .dprobes file (gets PID suffix at runtime)
/// - **module**: Automatically derived from binary name
/// - **function**: Automatically derived from Swift function (mangled name)
/// - **name**: Defined in .dprobes file
///
/// Module and function cannot be customized for USDT probes - they are
/// determined by the object file structure. Use wildcards when tracing:
/// `myapp*:::request` matches any module/function.
///
/// ## Performance
///
/// - **Not tracing**: ~2-5ns (IS-ENABLED branch check)
/// - **Tracing**: ~600ns (kernel trap + argument copy)
///
/// Arguments use `@autoclosure` so they're only evaluated when tracing.
public enum DProbes {
    public static let version = "0.1.0"
}
