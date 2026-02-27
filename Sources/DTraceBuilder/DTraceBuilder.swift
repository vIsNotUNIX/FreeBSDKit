/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

@_exported import DTraceCore

/// DTraceBuilder - A fluent, opinionated API for DTrace.
///
/// This module provides Swift-native builders and helpers on top of `DTraceCore`.
/// Use this when you want a guided, type-safe experience for building D scripts.
///
/// ## Quick Start
///
/// ```swift
/// import DTraceBuilder
///
/// // Create a session with fluent configuration
/// let session = try DTraceSession()
///     .trace("syscall:::entry")
///     .targeting(.execname("nginx"))
///     .counting(by: .function)
///     .start()
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
/// ## Building Scripts Manually
///
/// ```swift
/// let script = DTraceScript("syscall::open*:entry")
///     .targeting(.pid(1234))
///     .printf("opened: %s", "copyinstr(arg0)")
///
/// print(script.build())  // See the generated D code
/// ```
///
/// For raw libdtrace access, use `DTraceCore.DTraceHandle` directly.
public enum DTraceBuilder {
    /// The version of DTraceBuilder.
    public static let version = "1.0.0"
}
