/*
 * DProbes - Type Definitions
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - DTraceConvertible Protocol

/// Protocol for types that can be passed as DTrace probe arguments.
///
/// DTrace USDT probes pass all arguments as `uintptr_t`. Types must either:
/// - Fit in a register (integers, bool)
/// - Be a pointer to data (strings)
///
/// ## Adding a New Type
///
/// 1. Add Swift→C mapping in `dprobes-gen` `swiftTypeToCType()`
/// 2. Add special handling in `generateProbeFunction()` if needed
/// 3. Add conformance here
public protocol DTraceConvertible {
    associatedtype DTraceRepresentation: DTraceConvertible
    var dtraceValue: DTraceRepresentation { get }
}

// MARK: - Integer Conformances

extension Int8: DTraceConvertible {
    public var dtraceValue: Int8 { self }
}

extension Int16: DTraceConvertible {
    public var dtraceValue: Int16 { self }
}

extension Int32: DTraceConvertible {
    public var dtraceValue: Int32 { self }
}

extension Int64: DTraceConvertible {
    public var dtraceValue: Int64 { self }
}

extension Int: DTraceConvertible {
    public var dtraceValue: Int { self }
}

extension UInt8: DTraceConvertible {
    public var dtraceValue: UInt8 { self }
}

extension UInt16: DTraceConvertible {
    public var dtraceValue: UInt16 { self }
}

extension UInt32: DTraceConvertible {
    public var dtraceValue: UInt32 { self }
}

extension UInt64: DTraceConvertible {
    public var dtraceValue: UInt64 { self }
}

extension UInt: DTraceConvertible {
    public var dtraceValue: UInt { self }
}

// MARK: - Bool Conformance

extension Bool: DTraceConvertible {
    public var dtraceValue: Int32 { self ? 1 : 0 }
}

// MARK: - String Conformances

extension String: DTraceConvertible {
    public var dtraceValue: UInt { 0 }

    @inlinable
    public func withDTracePointer<R>(_ body: (UInt) -> R) -> R {
        self.withCString { ptr in
            body(UInt(bitPattern: ptr))
        }
    }
}

extension StaticString: DTraceConvertible {
    public var dtraceValue: UInt {
        UInt(bitPattern: utf8Start)
    }
}

extension Optional: DTraceConvertible where Wrapped == String {
    public var dtraceValue: UInt { 0 }

    @inlinable
    public func withDTracePointer<R>(_ body: (UInt) -> R) -> R {
        switch self {
        case .none:
            return body(0)
        case .some(let s):
            return s.withCString { ptr in
                body(UInt(bitPattern: ptr))
            }
        }
    }
}

// MARK: - Pointer Conformances

extension UnsafeRawPointer: DTraceConvertible {
    public var dtraceValue: UInt { UInt(bitPattern: self) }
}

extension UnsafeMutableRawPointer: DTraceConvertible {
    public var dtraceValue: UInt { UInt(bitPattern: self) }
}

extension OpaquePointer: DTraceConvertible {
    public var dtraceValue: UInt { UInt(bitPattern: self) }
}

// MARK: - Constraints

/// DTrace constraints enforced by dprobes-gen.
public enum DTraceConstraints {
    /// Maximum arguments per probe (DTrace USDT limit).
    public static let maxArguments = 10

    /// Maximum provider name length.
    public static let maxProviderNameLength = 64

    /// Maximum probe name length.
    public static let maxProbeNameLength = 64

    /// Maximum module name length.
    public static let maxModuleNameLength = 64
}

// MARK: - Stability

/// Stability level for DTrace providers.
///
/// Communicates to consumers how likely the probe interface is to change.
public enum ProbeStability: String {
    case `private` = "Private"
    case project = "Project"
    case evolving = "Evolving"
    case stable = "Stable"
    case standard = "Standard"
}
