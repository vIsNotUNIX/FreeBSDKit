/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CJails
import FreeBSDKit
import Glibc

/// A safe builder for `iovec` arrays used with `jail_set(2)` and `jail_get(2)`.
///
/// `JailIOVector` constructs a sequence of key/value `iovec` pairs suitable for
/// passing to the FreeBSD jail system calls. Each parameter is represented as
/// two consecutive `iovec` entries: a NUL-terminated parameter name followed by
/// its value.
///
/// The builder owns all backing storage for the duration of its lifetime and
/// guarantees that all pointers remain valid while the instance is alive.
///
/// - Important: Callers must not retain pointers obtained from `iovecs` beyond
///   the lifetime of this object.
/// - Note: This type is not thread-safe.
/// - SeeAlso: `jail_set(2)`, `jail_get(2)`
public final class JailIOVector {

    /// The constructed `iovec` array.
    ///
    /// The array always contains an even number of elements and is ordered as:
    ///
    /// ```
    /// [name, value, name, value, ...]
    /// ```
    ///
    /// Access is provided via `withUnsafeMutableIOVecs` to prevent dangling pointers.
    private var iovecs: [iovec] = []

    private var storage: [UnsafeMutableRawPointer] = []

    /// Creates an empty jail I/O vector builder.
    public init() {}

    deinit {
        for ptr in storage {
            free(ptr)
        }
    }

    /// Adds a string-valued jail parameter.
    ///
    /// The parameter name and value are encoded as NUL-terminated C strings.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The string value to associate with the parameter.
    ///
    /// - SeeAlso: `jail_set(2)`
    public func addCString(
        _ name: String,
        value: String
    ) throws {
        let key: UnsafeMutablePointer<CChar> = try name.withCString { cName in
            guard let p = strdup(cName) else {
                try BSDError.throwErrno()
            }
            return p
        }

        let val: UnsafeMutablePointer<CChar> = try value.withCString { cVal in
            guard let p = strdup(cVal) else {
                free(key)
                try BSDError.throwErrno()
            }
            return p
        }

        storage.append(UnsafeMutableRawPointer(key))
        storage.append(UnsafeMutableRawPointer(val))

        appendPair(
            key: UnsafeMutableRawPointer(key),
            keyLen: Int(strlen(key) + 1),
            value: UnsafeMutableRawPointer(val),
            valueLen: Int(strlen(val) + 1)
        )
    }


    /// Adds a 32-bit signed integer jail parameter.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The `Int32` value to associate with the parameter.
    public func addInt32(_ name: String, _ value: Int32) throws {
        try addScalar(name: name, value: value)
    }

    /// Adds a 32-bit unsigned integer jail parameter.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The `UInt32` value to associate with the parameter.
    public func addUInt32(_ name: String, _ value: UInt32) throws {
        try addScalar(name: name, value: value)
    }

    /// Adds a 64-bit signed integer jail parameter.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The `Int64` value to associate with the parameter.
    public func addInt64(_ name: String, _ value: Int64) throws {
        try addScalar(name: name, value: value)
    }

    /// Adds a Boolean jail parameter.
    ///
    /// The value is encoded as an `Int32` with `1` representing `true` and `0`
    /// representing `false`, matching the jail ABI.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The Boolean value to associate with the parameter.
    public func addBool(_ name: String, _ value: Bool) throws {
        let v: Int32 = value ? 1 : 0
        try addScalar(name: name, value: v)
    }

    /// Adds a scalar-valued jail parameter.
    ///
    /// The parameter name is encoded as a NUL-terminated C string, and the scalar
    /// value is copied into newly allocated memory using the native byte order and
    /// width of `T`. The allocated buffers are retained internally and later passed
    /// to `jail_set(2)` or `jail_get(2)`.
    ///
    /// This method performs heap allocation and may fail if memory cannot be
    /// allocated, in which case it throws a system error derived from `errno`.
    ///
    /// - Parameters:
    ///   - name: The jail parameter name.
    ///   - value: The scalar value to associate with the parameter.
    ///
    /// - Throws: A `SystemError` if memory allocation fails.
    ///
    /// - Important: The memory allocated by this method is owned by the receiver
    ///   and must be released by it at the appropriate time.
    private func addScalar<T>(
        name: String,
        value: T
    ) throws where T: FixedWidthInteger {

        let key: UnsafeMutablePointer<CChar> = try name.withCString { cName in
            guard let p = strdup(cName) else {
                try BSDError.throwErrno()
            }
            return p
        }

        let size = MemoryLayout<T>.size
        guard let val = malloc(size) else {
            free(key)
            try BSDError.throwErrno()
        }

        val.storeBytes(of: value, as: T.self)

        storage.append(UnsafeMutableRawPointer(key))
        storage.append(val)

        appendPair(
            key: UnsafeMutableRawPointer(key),
            keyLen: Int(strlen(key) + 1),
            value: val,
            valueLen: size
        )
    }

    /// The number of `iovec` entries (always even: name/value pairs).
    public var count: Int {
        return iovecs.count
    }

    /// Provides unsafe mutable access to the underlying `iovec` array.
    ///
    /// The pointer is only valid for the duration of the closure. Do not retain
    /// pointers beyond the closure's scope.
    ///
    /// - Parameter body: A closure that takes an `UnsafeMutableBufferPointer<iovec>`.
    /// - Returns: The value returned by the closure.
    public func withUnsafeMutableIOVecs<R>(
        _ body: (UnsafeMutableBufferPointer<iovec>) throws -> R
    ) rethrows -> R {
        return try iovecs.withUnsafeMutableBufferPointer { buf in
            try body(buf)
        }
    }

    @inline(__always)
    private func appendPair(
        key: UnsafeMutableRawPointer,
        keyLen: Int,
        value: UnsafeMutableRawPointer,
        valueLen: Int
    ) {
        iovecs.append(iovec(iov_base: key, iov_len: size_t(keyLen)))
        iovecs.append(iovec(iov_base: value, iov_len: size_t(valueLen)))

        assert(
            iovecs.count % 2 == 0,
            "iovecs must contain key/value pairs"
        )
    }
}