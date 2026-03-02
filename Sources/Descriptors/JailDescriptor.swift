/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
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
    /// Attaches the current process to this jail.
    func attach() throws

    /// Removes the jail this descriptor refers to.
    func remove() throws

    /// Creates or updates a jail and returns a descriptor.
    static func set(iov: inout JailIOVector, flags: JailSetFlags) throws -> Self

    /// Looks up a jail and returns a descriptor.
    static func get(iov: inout JailIOVector, flags: JailGetFlags) throws -> Self
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
    ///
    /// The caller must have added a descriptor output buffer to the iov using
    /// `addDescriptorOutput()` and include `getDesc` or `ownDesc` in the flags.
    ///
    /// - Parameters:
    ///   - iov: The jail I/O vector containing query parameters and a desc output buffer.
    ///   - flags: Flags controlling the operation. Must include `.getDesc` or `.ownDesc`.
    /// - Returns: A jail descriptor.
    /// - Throws: `BSDError` if the jail doesn't exist or descriptor creation fails.
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

    /// Opens a jail descriptor for an existing jail by name.
    ///
    /// - Parameters:
    ///   - name: The jail name.
    ///   - owning: If true, return an owning descriptor that will remove the jail when closed.
    /// - Returns: A jail descriptor.
    /// - Throws: `BSDError` if the jail doesn't exist.
    public static func open(name: String, owning: Bool = false) throws -> SystemJailDescriptor {
        let iov = JailIOVector()
        try iov.addCString("name", value: name)

        let descBuf = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer { descBuf.deallocate() }
        descBuf.pointee = -1

        try iov.addDescriptorOutput(buffer: descBuf)

        var flags: JailGetFlags = [.getDesc]
        if owning {
            flags.insert(.ownDesc)
        }

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
            try BSDError.throwErrno(errno)
        }

        guard descBuf.pointee >= 0 else {
            throw POSIXError(.EBADF)
        }

        return SystemJailDescriptor(descBuf.pointee)
    }

    /// Opens a jail descriptor for an existing jail by JID.
    ///
    /// - Parameters:
    ///   - jid: The jail ID.
    ///   - owning: If true, return an owning descriptor that will remove the jail when closed.
    /// - Returns: A jail descriptor.
    /// - Throws: `BSDError` if the jail doesn't exist.
    public static func open(jid: Int32, owning: Bool = false) throws -> SystemJailDescriptor {
        let iov = JailIOVector()
        try iov.addInt32("jid", jid)

        let descBuf = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer { descBuf.deallocate() }
        descBuf.pointee = -1

        try iov.addDescriptorOutput(buffer: descBuf)

        var flags: JailGetFlags = [.getDesc]
        if owning {
            flags.insert(.ownDesc)
        }

        let result = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard result >= 0 else {
            try BSDError.throwErrno(errno)
        }

        guard descBuf.pointee >= 0 else {
            throw POSIXError(.EBADF)
        }

        return SystemJailDescriptor(descBuf.pointee)
    }

    /// Create or update a jail and return a descriptor.
    ///
    /// The caller must have added a descriptor output buffer to the iov using
    /// `addDescriptorOutput()` and include `getDesc` or `ownDesc` in the flags.
    ///
    /// - Parameters:
    ///   - iov: The jail I/O vector containing jail parameters and a desc output buffer.
    ///   - flags: Flags controlling the operation. Must include `.getDesc` or `.ownDesc`.
    /// - Returns: A jail descriptor for the created/updated jail.
    /// - Throws: `BSDError` if jail creation fails.
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

    /// Creates a new jail and returns an owning descriptor.
    ///
    /// - Parameters:
    ///   - config: The jail configuration.
    ///   - shouldAttach: If true, attach the calling process to the jail.
    /// - Returns: An owning jail descriptor that will remove the jail when closed.
    /// - Throws: `BSDError` if jail creation fails.
    public static func create(
        _ config: JailConfiguration,
        attach shouldAttach: Bool = false
    ) throws -> SystemJailDescriptor {
        let iov = JailIOVector()
        try config.populate(into: iov)

        let descBuf = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer { descBuf.deallocate() }
        descBuf.pointee = -1

        try iov.addDescriptorOutput(buffer: descBuf)

        var flags: JailSetFlags = [.create, .getDesc, .ownDesc]
        if shouldAttach {
            flags.insert(.attach)
        }

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_set(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        guard jid >= 0 else {
            try BSDError.throwErrno(errno)
        }

        guard descBuf.pointee >= 0 else {
            throw POSIXError(.EBADF)
        }

        return SystemJailDescriptor(descBuf.pointee)
    }

    /// Gets information about the jail this descriptor refers to.
    ///
    /// - Returns: Jail info, or nil if the jail has been removed.
    public func info() throws -> JailInfo? {
        let iov = JailIOVector()

        try iov.addInt32("desc", fd)

        let nameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { nameBuf.deallocate() }
        nameBuf.initialize(repeating: 0, count: 256)

        let pathBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
        defer { pathBuf.deallocate() }
        pathBuf.initialize(repeating: 0, count: 1024)

        let hostnameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { hostnameBuf.deallocate() }
        hostnameBuf.initialize(repeating: 0, count: 256)

        try iov.addOutputBuffer("name", buffer: nameBuf, size: 256)
        try iov.addOutputBuffer("path", buffer: pathBuf, size: 1024)
        try iov.addOutputBuffer("host.hostname", buffer: hostnameBuf, size: 256)

        let flags: JailGetFlags = [.useDesc]

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
        }

        if jid < 0 {
            if errno == ENOENT {
                return nil
            }
            try BSDError.throwErrno(errno)
        }

        return JailInfo(
            jid: jid,
            name: String(cString: nameBuf),
            path: String(cString: pathBuf),
            hostname: String(cString: hostnameBuf)
        )
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

                // Jail descriptors are returned in the "desc" parameter
                if strcmp(key, "desc") == 0 {
                    guard valIOV.iov_len == MemoryLayout<RawDesc>.size,
                        let valBase = valIOV.iov_base
                    else { throw POSIXError(.EINVAL) }

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