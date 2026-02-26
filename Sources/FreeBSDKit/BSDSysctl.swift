/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// Forward declare sysctlbyname from libc
@_silgen_name("sysctlbyname")
private func sysctlbyname(
    _ name: UnsafePointer<CChar>,
    _ oldp: UnsafeMutableRawPointer?,
    _ oldlenp: UnsafeMutablePointer<Int>,
    _ newp: UnsafeRawPointer?,
    _ newlen: Int
) -> Int32

/// Swift-friendly interface to FreeBSD sysctl system.
///
/// Provides type-safe reading and writing of sysctl values.
///
/// ## Example
/// ```swift
/// // Read values
/// let maxSeqpacket: Int32 = try BSDSysctl.get("net.local.seqpacket.maxseqpacket")
/// let hostname: String = try BSDSysctl.get("kern.hostname")
/// let boottime: timeval = try BSDSysctl.get("kern.boottime")
///
/// // Write values
/// try BSDSysctl.set("kern.hostname", value: "newhost")
/// ```
public enum BSDSysctl {

    // MARK: - Generic Get/Set

    /// Reads a sysctl value of the specified type.
    ///
    /// Use this for type-safe sysctl reading. The compiler will infer the type
    /// from your variable declaration.
    ///
    /// - Parameter name: The sysctl name (e.g., "net.local.seqpacket.maxseqpacket")
    /// - Returns: The sysctl value as type T
    /// - Throws: `BSDError` if the sysctl doesn't exist or cannot be read
    ///
    /// - Warning: Type T must be a trivial type (POD) with no padding. Using this
    ///   with non-trivial types or types that don't match the sysctl's actual type
    ///   may result in undefined behavior. Always verify the sysctl's type using
    ///   `sysctl -t` before use.
    public static func get<T>(_ name: String) throws -> T {
        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        )
        defer { ptr.deallocate() }

        var size = MemoryLayout<T>.size

        let result = name.withCString { namePtr in
            sysctlbyname(namePtr, ptr, &size, nil, 0)
        }

        guard result == 0 else {
            try BSDError.throwErrno(errno)
        }

        return ptr.load(as: T.self)
    }

    /// Writes a sysctl value.
    ///
    /// - Parameters:
    ///   - name: The sysctl name
    ///   - value: The new value to set
    /// - Throws: `BSDError` if the sysctl doesn't exist or cannot be written
    public static func set<T>(_ name: String, value: T) throws {
        var mutableValue = value
        var dummySize = 0
        let result = name.withCString { namePtr in
            withUnsafeBytes(of: &mutableValue) { bytes in
                sysctlbyname(namePtr, nil, &dummySize, bytes.baseAddress, bytes.count)
            }
        }

        guard result == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    // MARK: - String Specializations

    /// Reads a string sysctl value.
    ///
    /// This is a specialized version for strings since they're variable-length.
    ///
    /// - Parameter name: The sysctl name
    /// - Returns: The sysctl value as a string
    /// - Throws: `BSDError` if the sysctl doesn't exist or cannot be read
    public static func getString(_ name: String) throws -> String {
        // First, get the size needed
        var size = 0
        let result = name.withCString { namePtr in
            sysctlbyname(namePtr, nil, &size, nil, 0)
        }

        guard result == 0 else {
            try BSDError.throwErrno(errno)
        }

        // Allocate buffer and read the string
        var buffer = [CChar](repeating: 0, count: size)
        let readResult = name.withCString { namePtr in
            sysctlbyname(namePtr, &buffer, &size, nil, 0)
        }

        guard readResult == 0 else {
            try BSDError.throwErrno(errno)
        }

        return buffer.withUnsafeBytes { ptr in
            let utf8 = ptr.bindMemory(to: UInt8.self)
            let length = utf8.firstIndex(of: 0) ?? utf8.count
            return String(decoding: utf8.prefix(length), as: UTF8.self)
        }
    }

    /// Writes a string sysctl value.
    ///
    /// - Parameters:
    ///   - name: The sysctl name
    ///   - value: The new string value to set
    /// - Throws: `BSDError` if the sysctl doesn't exist or cannot be written
    public static func setString(_ name: String, value: String) throws {
        var dummySize = 0
        let result = value.withCString { valuePtr in
            name.withCString { namePtr in
                sysctlbyname(namePtr, nil, &dummySize, valuePtr, value.utf8.count + 1)
            }
        }

        guard result == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    // MARK: - Subscript Access

    /// Subscript-based access to sysctl values.
    ///
    /// ## Example
    /// ```swift
    /// let value: Int32 = try BSDSysctl["net.local.seqpacket.maxseqpacket"]
    /// let hostname: String = try BSDSysctl.string["kern.hostname"]
    /// ```
    public static subscript<T>(_ name: String) -> T {
        get throws {
            try get(name)
        }
    }

    /// Subscript for string sysctl values.
    public static var string: StringSubscript {
        StringSubscript()
    }

    public struct StringSubscript {
        public subscript(_ name: String) -> String {
            get throws {
                try getString(name)
            }
        }
    }
}
