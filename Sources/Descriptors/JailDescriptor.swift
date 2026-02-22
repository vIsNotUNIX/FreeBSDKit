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

// MARK: - JailDescriptorInfo

/// Wraps a jail descriptor along with its ownership flag.
///
/// Since `SystemJailDescriptor` is noncopyable, it cannot be returned in a tuple.
/// This struct provides a way to return both the descriptor and the owning flag together.
///
/// Jail descriptors can be marked as "owning", which indicates that the holder has
/// permission to remove the jail. The ownership flag is transmitted separately from
/// the descriptor itself in protocols like BPC.
public struct JailDescriptorInfo: ~Copyable {
    /// The jail descriptor.
    public let descriptor: SystemJailDescriptor

    /// Whether this descriptor owns the jail (can remove it).
    public let owning: Bool

    /// Creates a jail descriptor info with the specified descriptor and ownership flag.
    public init(descriptor: consuming SystemJailDescriptor, owning: Bool) {
        self.descriptor = consume descriptor
        self.owning = owning
    }
}

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
               try BSDError.throwErrno(errno)
            }
        }
    }

    func remove() throws {
        try self.unsafe { fd in
            guard jail_remove_jd(fd) == 0 else {
               try BSDError.throwErrno(errno)
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
        let desc = fd
        fd = -1
        return desc
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
           try BSDError.throwErrno(errno)
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
           try BSDError.throwErrno(errno)
        }

        let fd = try extractDescFD(from: &iov)
        return SystemJailDescriptor(fd)
    }


    private static func extractDescFD(from iov: inout JailIOVector) throws -> RawDesc {
        try iov.withUnsafeMutableIOVecs { buf in
            guard buf.count % 2 == 0 else {
                throw POSIXError(.EINVAL)
            }

            var i = 0
            while i < buf.count {
                let keyIOV = buf[i]
                let valIOV = buf[i + 1]

                guard let keyBase = keyIOV.iov_base else { i += 2; continue }
                let key = keyBase.assumingMemoryBound(to: CChar.self)

                if strcmp(key, "jid") == 0 {
                    guard valIOV.iov_len == MemoryLayout<RawDesc>.size,
                        let valBase = valIOV.iov_base
                    else { throw POSIXError(.EINVAL) }

                    // Alignment is OK because you allocated scalars via malloc().
                    let fd = valBase.load(as: RawDesc.self)
                    guard fd >= 0 else { throw POSIXError(.EBADF) }
                    return fd
                }

                i += 2
            }

            throw POSIXError(.EINVAL)
        }
    }
}