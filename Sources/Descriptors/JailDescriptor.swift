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
    static 
    func set(iov: inout JailIOVector, flags: JailSetFlags) throws -> Self
    static
    func get(iov: inout JailIOVector, flags: JailGetFlags) throws -> Self
}

public extension JailDescriptor where Self: ~Copyable {

    func attach() throws {
        try self.unsafe { fd in
            guard jail_attach_jd(fd) == 0 else {
               throw BSDErrno.throwErrno(errno)
            }
        }
    }

    func remove() throws {
        try self.unsafe { fd in
            guard jail_remove_jd(fd) == 0 else {
               throw BSDErrno.throwErrno(errno)
            }
        }
    }
}

// MARK: - Concrete Jail Descriptor

public struct SystemJailDescriptor: JailDescriptor, ~Copyable {

    public typealias RAWBSD = RawDesc
    private var fd: RawDesc

    public init(_ value: RAWBSD) {
        self.fd = value
    }

    consuming public func close() {
        if fd >= 0 {
            _ = Glibc.close(fd)
            fd = -1
        }
    }

    consuming public func take() -> RAWBSD {
        return fd
    }

    public func unsafe<R>(
        _ block: (RAWBSD) throws -> R
    ) rethrows -> R where R: ~Copyable {
        try block(fd)
    }

    /// Lookup a jail and return a descriptor.
    public static func get(
        iov: inout JailIOVector,
        flags: JailGetFlags
    ) throws -> SystemJailDescriptor {

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
           throw BSDErrno.throwErrno(errno)
        }

        let fd = try extractDescFD(from: &iov)
        return SystemJailDescriptor(fd)
    }


    /// Create or update a jail and return a descriptor.
    public static func set(
        iov: inout JailIOVector,
        flags: JailSetFlags
    ) throws -> SystemJailDescriptor {

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_set(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
           throw BSDErrno.throwErrno(errno)
        }

        let fd = try extractDescFD(from: &iov)
        return SystemJailDescriptor(fd)
    }


    private static func extractDescFD(
        from iov: inout JailIOVector
    ) throws -> RawDesc {

        let fd: RawDesc? = iov.withUnsafeMutableIOVecs { buf in
            for entry in buf {
                guard entry.iov_len == MemoryLayout<RawDesc>.size,
                    let base = entry.iov_base
                else { continue }

                return base.load(as: RawDesc.self)
            }
            return nil
        }

        guard let fd else {
            throw POSIXError(.EINVAL)
        }

        return fd
    }
}