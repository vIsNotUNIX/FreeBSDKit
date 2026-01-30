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
import Jails
import Glibc
import Foundation
import FreeBSDKit



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