/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Foundation
import Glibc

/// Sysctl access service for Capsicum sandboxes.
///
/// `CasperSysctl` wraps a Casper sysctl service channel and provides type-safe
/// Swift interfaces to sysctl functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let sysctl = try CasperSysctl(casper: casper)
///
/// // Limit to specific sysctls
/// try sysctl.limitNames([
///     ("kern.hostname", .read),
///     ("hw.physmem", .read)
/// ])
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Read sysctl values
/// let hostname: String = try sysctl.getString("kern.hostname")
/// let physmem: Int64 = try sysctl.get("hw.physmem")
/// ```
public struct CasperSysctl: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a sysctl service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the sysctl service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.sysctl)
    }

    /// Creates a sysctl service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the sysctl service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Sysctl access flags.
    public struct AccessFlags: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Allow reading the sysctl.
        public static let read = AccessFlags(rawValue: CCASPER_SYSCTL_READ)
        /// Allow writing the sysctl.
        public static let write = AccessFlags(rawValue: CCASPER_SYSCTL_WRITE)
        /// Allow reading and writing.
        public static let readWrite = AccessFlags(rawValue: CCASPER_SYSCTL_RDWR)
        /// Match all sysctls under this prefix (recursive).
        public static let recursive = AccessFlags(rawValue: CCASPER_SYSCTL_RECURSIVE)
    }

    /// Limits the sysctl service to specific sysctl names.
    ///
    /// - Parameter names: Tuples of (sysctl name, access flags).
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitNames(_ names: [(String, AccessFlags)]) throws {
        let limitPtr = channel.withUnsafeChannel { chan in
            ccasper_sysctl_limit_init(chan)
        }

        guard var limit = limitPtr else {
            throw CasperError.limitSetFailed(errno: ENOMEM)
        }

        for (name, flags) in names {
            limit = name.withCString { namePtr in
                ccasper_sysctl_limit_name(limit, namePtr, flags.rawValue)
            }
        }

        let result = ccasper_sysctl_limit(limit)
        if result != 0 {
            throw CasperError.limitSetFailed(errno: errno)
        }
    }

    /// Reads a sysctl value of the specified type.
    ///
    /// - Parameter name: The sysctl name (e.g., "kern.osreldate").
    /// - Returns: The sysctl value as type T.
    /// - Throws: `CasperError.operationFailed` if the read fails.
    ///
    /// - Warning: Type T must be a trivial type (POD) with no padding.
    public func get<T>(_ name: String) throws -> T {
        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        )
        defer { ptr.deallocate() }

        var size = MemoryLayout<T>.size

        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_sysctlbyname(chan, namePtr, ptr, &size, nil, 0)
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }

        return ptr.load(as: T.self)
    }

    /// Writes a sysctl value.
    ///
    /// - Parameters:
    ///   - name: The sysctl name.
    ///   - value: The new value to set.
    /// - Throws: `CasperError.operationFailed` if the write fails.
    public func set<T>(_ name: String, value: T) throws {
        var mutableValue = value
        var dummySize = 0

        let result = name.withCString { namePtr in
            withUnsafeBytes(of: &mutableValue) { bytes in
                channel.withUnsafeChannel { chan in
                    ccasper_sysctlbyname(chan, namePtr, nil, &dummySize, bytes.baseAddress, bytes.count)
                }
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Reads a string sysctl value.
    ///
    /// - Parameter name: The sysctl name.
    /// - Returns: The sysctl value as a string.
    /// - Throws: `CasperError.operationFailed` if the read fails.
    public func getString(_ name: String) throws -> String {
        // First, get the size needed
        var size = 0

        var result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_sysctlbyname(chan, namePtr, nil, &size, nil, 0)
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }

        // Allocate buffer and read the string
        var buffer = [CChar](repeating: 0, count: size)

        result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_sysctlbyname(chan, namePtr, &buffer, &size, nil, 0)
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
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
    ///   - name: The sysctl name.
    ///   - value: The new string value.
    /// - Throws: `CasperError.operationFailed` if the write fails.
    public func setString(_ name: String, value: String) throws {
        var dummySize = 0

        let result = value.withCString { valuePtr in
            name.withCString { namePtr in
                channel.withUnsafeChannel { chan in
                    ccasper_sysctlbyname(chan, namePtr, nil, &dummySize, valuePtr, value.utf8.count + 1)
                }
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Converts a sysctl name to its MIB representation.
    ///
    /// - Parameter name: The sysctl name.
    /// - Returns: The MIB as an array of integers.
    /// - Throws: `CasperError.operationFailed` if the conversion fails.
    public func nameToMIB(_ name: String) throws -> [Int32] {
        var mib = [Int32](repeating: 0, count: Int(CCASPER_CTL_MAXNAME))
        var size = mib.count

        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_sysctlnametomib(chan, namePtr, &mib, &size)
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }

        return Array(mib.prefix(size))
    }

    /// Reads a sysctl using its MIB representation.
    ///
    /// - Parameter mib: The MIB array.
    /// - Returns: The sysctl value as type T.
    /// - Throws: `CasperError.operationFailed` if the read fails.
    public func get<T>(mib: [Int32]) throws -> T {
        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        )
        defer { ptr.deallocate() }

        var size = MemoryLayout<T>.size
        var mutableMIB = mib

        let result = mutableMIB.withUnsafeMutableBufferPointer { mibBuffer in
            channel.withUnsafeChannel { chan in
                ccasper_sysctl(chan, mibBuffer.baseAddress, UInt32(mibBuffer.count), ptr, &size, nil, 0)
            }
        }

        guard result == 0 else {
            throw CasperError.operationFailed(errno: errno)
        }

        return ptr.load(as: T.self)
    }
}
