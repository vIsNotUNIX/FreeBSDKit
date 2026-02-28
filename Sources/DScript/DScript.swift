/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

@_exported import DTraceCore

/// DScript - A type-safe, result builder API for DTrace.
///
/// This module provides Swift-native builders and helpers on top of `DTraceCore`.
/// Use this when you want a guided, type-safe experience for building D scripts.
///
/// ## Quick Start
///
/// ```swift
/// import DScript
///
/// // Build a script with the DScript result builder
/// let script = DScript {
///     Probe("syscall:::entry") {
///         Target(.execname("nginx"))
///         Count(by: "probefunc")
///     }
/// }
///
/// // Run it in a session
/// var session = try DScriptSession.run(script)
///
/// // Process trace data
/// while session.work() == .okay {
///     session.sleep()
/// }
///
/// // Print aggregations
/// try session.printAggregations()
/// ```
///
/// ## Building Scripts
///
/// ```swift
/// let script = DScript {
///     Probe("syscall::open*:entry") {
///         Target(.pid(1234))
///         Printf("opened: %s", "copyinstr(arg0)")
///     }
/// }
///
/// print(script.source)  // See the generated D code
/// ```
///
/// For raw libdtrace access, use `DTraceCore.DTraceHandle` directly.
