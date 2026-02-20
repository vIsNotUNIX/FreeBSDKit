/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - Constants

/// Constant for anonymous shared memory.
/// When passed as the name to shm_open(), creates an unnamed shared memory object
/// that can be passed via descriptor passing but doesn't require namespace access.
/// This is safe to use in capability mode.
public let SHM_ANON = UnsafeMutablePointer<CChar>(bitPattern: 1)!

// MARK: - Open Flags

/// Flags for opening shared memory objects.
public struct ShmOpenFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Open for reading
    public static let readOnly  = ShmOpenFlags(rawValue: O_RDONLY)
    /// Open for writing
    public static let writeOnly = ShmOpenFlags(rawValue: O_WRONLY)
    /// Open for reading and writing
    public static let readWrite = ShmOpenFlags(rawValue: O_RDWR)
    /// Create if it doesn't exist
    public static let create    = ShmOpenFlags(rawValue: O_CREAT)
    /// Ensure creation (fail if exists)
    public static let exclusive = ShmOpenFlags(rawValue: O_EXCL)
    /// Truncate to zero length
    public static let truncate  = ShmOpenFlags(rawValue: O_TRUNC)
}

// MARK: - Protection Flags

/// Memory protection options for POSIX shared memory mappings.
public struct ShmProtection: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let none  = ShmProtection(rawValue: PROT_NONE)
    public static let read  = ShmProtection(rawValue: PROT_READ)
    public static let write = ShmProtection(rawValue: PROT_WRITE)
    public static let exec  = ShmProtection(rawValue: PROT_EXEC)
}

// MARK: - Mapping Flags

/// Flags controlling how shared memory is mapped.
public struct ShmMapFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let shared  = ShmMapFlags(rawValue: MAP_SHARED)
    public static let `private` = ShmMapFlags(rawValue: MAP_PRIVATE)
    public static let fixed   = ShmMapFlags(rawValue: MAP_FIXED)
}

// MARK: - Mapped Region (Linear)

/// A linear handle to a memory-mapped region.
///
/// The region **must** be unmapped exactly once.
public struct MappedRegion: ~Copyable {
    public let base: UnsafeRawPointer
    public let size: Int

    init(base: UnsafeRawPointer, size: Int) {
        self.base = base
        self.size = size
    }

    init(
        fd: Int32,
        size: Int,
        protection: ShmProtection,
        flags: ShmMapFlags
    ) throws {
        let ptr = Glibc.mmap(
            nil,
            size,
            protection.rawValue,
            flags.rawValue,
            fd,
            0
        )
        
        guard ptr != MAP_FAILED else {
            try BSDError.throwErrno(errno)
        }

        self.base = UnsafeRawPointer(ptr!)
        self.size = size
    }

    /// Unmap the region.
    consuming public func unmap() throws {
        let res = Glibc.munmap(
            UnsafeMutableRawPointer(mutating: base),
            size
        )
        guard res == 0 else {
            try BSDError.throwErrno(errno)
        }
    }
}

/// A descriptor representing a POSIX shared memory object.
public protocol SharedMemoryDescriptor: Descriptor, ~Copyable {

    /// Open or create a POSIX shared memory object.
    static func open(
        name: String,
        flags: ShmOpenFlags,
        mode: mode_t
    ) throws -> Self

    /// Creates an anonymous shared memory object.
    ///
    /// Anonymous shared memory objects:
    /// - Have no name in the filesystem namespace
    /// - Can only be accessed via the returned descriptor
    /// - Are automatically cleaned up when all references are closed
    /// - Work in capability mode (no namespace access required)
    ///
    /// - Parameters:
    ///   - flags: Open flags (typically `.readWrite`)
    ///   - mode: Permission mode (usually `0o600`)
    /// - Returns: A new anonymous shared memory descriptor
    /// - Throws: BSD error if creation fails
    static func anonymous(flags: ShmOpenFlags, mode: mode_t) throws -> Self

    /// Remove the shared memory object name.
    static func unlink(name: String) throws

    /// Resize the shared memory object.
    func setSize(_ size: Int) throws

    /// Map the shared memory object.
    func map(
        size: Int,
        protection: ShmProtection,
        flags: ShmMapFlags
    ) throws -> MappedRegion
}

// MARK: - Default Implementations

public extension SharedMemoryDescriptor where Self: ~Copyable {

    static func open(
        name: String,
        flags: ShmOpenFlags,
        mode: mode_t = 0o600
    ) throws -> Self {
        let fd = name.withCString { ptr in
            Glibc.shm_open(ptr, flags.rawValue, mode)
        }
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(fd)
    }

    static func anonymous(flags: ShmOpenFlags = .readWrite, mode: mode_t = 0o600) throws -> Self {
        let fd = Glibc.shm_open(SHM_ANON, flags.rawValue, mode)
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(fd)
    }

    static func unlink(name: String) throws {
        let res = name.withCString { ptr in
            Glibc.shm_unlink(ptr)
        }
        guard res == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    func setSize(_ size: Int) throws {
        try self.unsafe { fd in
            guard Glibc.ftruncate(fd, off_t(size)) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func map(
        size: Int,
        protection: ShmProtection,
        flags: ShmMapFlags
    ) throws -> MappedRegion {
        try self.unsafe { fd in
            let ptr = Glibc.mmap(
                nil,
                size,
                protection.rawValue,
                flags.rawValue,
                fd,
                0
            )

            guard ptr != MAP_FAILED else {
                try BSDError.throwErrno(errno)
            }

            return MappedRegion(
                base: UnsafeRawPointer(ptr!),
                size: size
            )
        }
    }
}
