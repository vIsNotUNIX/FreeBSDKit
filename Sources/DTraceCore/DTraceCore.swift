/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CDTrace

/// DTraceCore - Raw Swift bindings for libdtrace.
///
/// This module provides a minimal, direct wrapper around libdtrace.
/// For a more opinionated, fluent API, see the `DTraceBuilder` module.
///
/// ## Example Usage
///
/// ```swift
/// import DTraceCore
///
/// let handle = try DTraceHandle.open()
/// let program = try handle.compile("syscall:::entry { @[probefunc] = count(); }")
/// try handle.exec(program)
/// try handle.go()
///
/// while handle.poll() == .okay {
///     handle.sleep()
/// }
/// ```
public enum DTraceCore {
    /// The libdtrace version this module was built against.
    public static var version: Int32 {
        cdtrace_version()
    }
}

/// Flags for opening a DTrace handle.
public struct DTraceOpenFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Do not open the dtrace(7D) device.
    public static let noDevice = DTraceOpenFlags(rawValue: Int32(CDTRACE_O_NODEV.rawValue))

    /// Do not load /system/object modules.
    public static let noSystem = DTraceOpenFlags(rawValue: Int32(CDTRACE_O_NOSYS.rawValue))

    /// Force D compiler to be LP64.
    public static let lp64 = DTraceOpenFlags(rawValue: Int32(CDTRACE_O_LP64.rawValue))

    /// Force D compiler to be ILP32.
    public static let ilp32 = DTraceOpenFlags(rawValue: Int32(CDTRACE_O_ILP32.rawValue))
}

/// Flags for D program compilation.
public struct DTraceCompileFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// DIF verbose mode: show each compiled DIFO.
    public static let verbose = DTraceCompileFlags(rawValue: UInt32(CDTRACE_C_DIFV.rawValue))

    /// Permit compilation of empty D source files.
    public static let allowEmpty = DTraceCompileFlags(rawValue: UInt32(CDTRACE_C_EMPTY.rawValue))

    /// Permit probe definitions that match zero probes.
    public static let allowZeroMatches = DTraceCompileFlags(rawValue: UInt32(CDTRACE_C_ZDEFS.rawValue))

    /// Interpret ambiguous specifiers as probes.
    public static let probeSpec = DTraceCompileFlags(rawValue: UInt32(CDTRACE_C_PSPEC.rawValue))

    /// Do not process D system libraries.
    public static let noLibs = DTraceCompileFlags(rawValue: UInt32(CDTRACE_C_NOLIBS.rawValue))
}

/// Status returned by the DTrace work loop.
public enum DTraceWorkStatus: Sendable, Equatable {
    /// An error occurred while processing.
    case error

    /// Status okay, continue processing.
    case okay

    /// Tracing is done (exit() was called or buffer filled).
    case done

    public init(from status: dtrace_workstatus_t) {
        switch status {
        case DTRACE_WORKSTATUS_ERROR:
            self = .error
        case DTRACE_WORKSTATUS_OKAY:
            self = .okay
        case DTRACE_WORKSTATUS_DONE:
            self = .done
        default:
            self = .error
        }
    }
}

/// Status of the DTrace session.
public enum DTraceStatus: Sendable, Equatable {
    /// No status; not yet time.
    case none

    /// Status okay.
    case okay

    /// exit() was called; tracing stopped.
    case exited

    /// Fill buffer filled; tracing stopped.
    case filled

    /// Tracing already stopped.
    case stopped

    public init(from status: Int32) {
        switch status {
        case Int32(CDTRACE_STATUS_NONE.rawValue):
            self = .none
        case Int32(CDTRACE_STATUS_OKAY.rawValue):
            self = .okay
        case Int32(CDTRACE_STATUS_EXITED.rawValue):
            self = .exited
        case Int32(CDTRACE_STATUS_FILLED.rawValue):
            self = .filled
        case Int32(CDTRACE_STATUS_STOPPED.rawValue):
            self = .stopped
        default:
            self = .none
        }
    }
}

/// Information about a compiled D program.
public struct DTraceProgramInfo: Sendable {
    /// Number of aggregates specified in the program.
    public let aggregates: UInt32

    /// Number of record-generating probes in the program.
    public let recordGenerators: UInt32

    /// Number of probes matched by the program.
    public let matches: UInt32

    /// Number of speculations specified in the program.
    public let speculations: UInt32

    public init(from info: dtrace_proginfo_t) {
        self.aggregates = info.dpi_aggregates
        self.recordGenerators = info.dpi_recgens
        self.matches = info.dpi_matches
        self.speculations = info.dpi_speculations
    }
}
