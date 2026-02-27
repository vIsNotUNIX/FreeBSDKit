/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// A description of a DTrace probe.
///
/// Probes are identified by four components forming the tuple:
/// `provider:module:function:name`
///
/// Examples:
/// - `syscall:freebsd:open:entry`
/// - `fbt:kernel:malloc:return`
/// - `pid1234:libc.so:malloc:entry`
public struct DTraceProbeDescription: Sendable, Hashable {
    /// The unique probe ID assigned by DTrace.
    public let id: UInt32

    /// The provider that supplies this probe (e.g., "syscall", "fbt", "pid").
    public let provider: String

    /// The module containing this probe (e.g., "kernel", library name).
    public let module: String

    /// The function associated with this probe.
    public let function: String

    /// The probe name (e.g., "entry", "return").
    public let name: String

    /// Creates a new probe description.
    public init(
        id: UInt32 = 0,
        provider: String,
        module: String,
        function: String,
        name: String
    ) {
        self.id = id
        self.provider = provider
        self.module = module
        self.function = function
        self.name = name
    }

    /// The full probe specification string.
    public var fullName: String {
        "\(provider):\(module):\(function):\(name)"
    }
}

extension DTraceProbeDescription: CustomStringConvertible {
    public var description: String {
        fullName
    }
}

extension DTraceProbeDescription: CustomDebugStringConvertible {
    public var debugDescription: String {
        "DTraceProbeDescription(id: \(id), \(fullName))"
    }
}
