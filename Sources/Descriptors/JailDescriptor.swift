/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.
 */

import CJails
import Glibc
import Foundation
import FreeBSDKit

// MARK: - Jail Flags

public struct JailSetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let create  = JailSetFlags(rawValue: JAIL_CREATE)
    public static let update  = JailSetFlags(rawValue: JAIL_UPDATE)
    public static let attach  = JailSetFlags(rawValue: JAIL_ATTACH)

    public static let useDesc = JailSetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc  = JailSetFlags(rawValue: JAIL_AT_DESC)
    public static let getDesc = JailSetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc = JailSetFlags(rawValue: JAIL_OWN_DESC)
}

public struct JailGetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let dying   = JailGetFlags(rawValue: JAIL_DYING)
    public static let useDesc = JailGetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc  = JailGetFlags(rawValue: JAIL_AT_DESC)
    public static let getDesc = JailGetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc = JailGetFlags(rawValue: JAIL_OWN_DESC)
}

// MARK: - Jail Descriptor Protocol

/// A capability handle to a FreeBSD jail.
public protocol JailDescriptor: Descriptor, ~Copyable {
    func attach() throws
    func remove() throws
}

public extension JailDescriptor where Self: ~Copyable {

    func attach() throws {
        try self.unsafe { fd in
            guard jail_attach_jd(fd) == 0 else {
                throw POSIXError(.init(rawValue: errno)!)
            }
        }
    }

    func remove() throws {
        try self.unsafe { fd in
            guard jail_remove_jd(fd) == 0 else {
                throw POSIXError(.init(rawValue: errno)!)
            }
        }
    }
}

// MARK: - Concrete Jail Descriptor

public struct SystemJailDescriptor: JailDescriptor, ~Copyable {

    public typealias RAWBSD = Int32
    private var fd: Int32

    public init(_ value: Int32) {
        self.fd = value
    }

    consuming public func close() {
        if fd >= 0 {
            _ = Glibc.close(fd)
            fd = -1
        }
    }

    consuming public func take() -> Int32 {
        return fd
    }

    public func unsafe<R>(
        _ block: (Int32) throws -> R
    ) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

// MARK: - Safe Jail IOVec Builder

/// Safe builder for `jail_set` / `jail_get` iovecs.
///
/// All pointer unsafety is contained inside this type.
public struct JailIOVector {

    fileprivate var iovecs: [iovec] = []
    fileprivate var backing: [Any] = []

    public init() {}

    /// Add a C-string parameter.
    public mutating func addCString(
        _ name: String,
        value: String
    ) {
        let key = strdup(name)
        let val = strdup(value)

        backing.append(key!)
        backing.append(val!)

        let keyVec = iovec(
            iov_base: UnsafeMutableRawPointer(key),
            iov_len: name.utf8.count + 1
        )

        let valueVec = iovec(
            iov_base: UnsafeMutableRawPointer(val),
            iov_len: value.utf8.count + 1
        )

        iovecs.append(keyVec)
        iovecs.append(valueVec)
    }
}

public extension JailIOVector {

    mutating func addInt32(_ name: String, _ value: Int32) {
        addRaw(name: name, value: value)
    }

    mutating func addUInt32(_ name: String, _ value: UInt32) {
        addRaw(name: name, value: value)
    }

    mutating func addInt64(_ name: String, _ value: Int64) {
        addRaw(name: name, value: value)
    }

    mutating func addBool(_ name: String, _ value: Bool) {
        let v: Int32 = value ? 1 : 0
        addRaw(name: name, value: v)
    }

    // MARK: - Internal raw helper (the only unsafe part)

    private mutating func addRaw<T>(
        name: String,
        value: T
    ) {
        precondition(MemoryLayout<T>.stride == MemoryLayout<T>.size,
                     "Type must be POD")

        let key = strdup(name)!
        let val = UnsafeMutablePointer<T>.allocate(capacity: 1)
        val.initialize(to: value)

        backing.append(key)
        backing.append(val)

        let keyVec = iovec(
            iov_base: UnsafeMutableRawPointer(key),
            iov_len: name.utf8.count + 1
        )

        let valueVec = iovec(
            iov_base: UnsafeMutableRawPointer(val),
            iov_len: MemoryLayout<T>.size
        )

        iovecs.append(keyVec)
        iovecs.append(valueVec)
    }
}


// MARK: - Jail Operations

public enum Jail {

    /// Create or update a jail and return a descriptor.
    public static func set(
        iov: inout JailIOVector,
        flags: JailSetFlags
    ) throws -> SystemJailDescriptor {

        let jid = iov.iovecs.withUnsafeMutableBufferPointer { buf in
            jail_set(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
            throw POSIXError(.init(rawValue: errno)!)
        }

        let fd = extractDescFD(from: &iov.iovecs)
        return SystemJailDescriptor(fd)
    }

    /// Lookup a jail and return a descriptor.
    public static func get(
        iov: inout JailIOVector,
        flags: JailGetFlags
    ) throws -> SystemJailDescriptor {

        let jid = iov.iovecs.withUnsafeMutableBufferPointer { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
            throw POSIXError(.init(rawValue: errno)!)
        }

        let fd = extractDescFD(from: &iov.iovecs)
        return SystemJailDescriptor(fd)
    }

    private static func extractDescFD(
        from iovecs: inout [iovec]
    ) -> Int32 {
        for entry in iovecs {
            guard entry.iov_len == MemoryLayout<Int32>.size,
                  let base = entry.iov_base else { continue }

            return base.load(as: Int32.self)
        }

        fatalError("jail descriptor not returned by kernel")
    }
}