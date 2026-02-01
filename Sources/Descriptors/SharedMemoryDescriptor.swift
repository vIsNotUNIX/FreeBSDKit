/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import Glibc
import Foundation
import FreeBSDKit

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
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
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
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
    }
}

/// A descriptor representing a POSIX shared memory object.
public protocol SharedMemoryDescriptor: Descriptor, ~Copyable {

    /// Open or create a POSIX shared memory object.
    static func open(
        name: String,
        oflag: Int32,
        mode: mode_t
    ) throws -> Self

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
        oflag: Int32,
        mode: mode_t
    ) throws -> Self {
        let fd = name.withCString { ptr in
            Glibc.shm_open(ptr, oflag, mode)
        }
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        return Self(fd)
    }

    static func unlink(name: String) throws {
        let res = name.withCString { ptr in
            Glibc.shm_unlink(ptr)
        }
        guard res == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
    }

    func setSize(_ size: Int) throws {
        try self.unsafe { fd in
            guard Glibc.ftruncate(fd, off_t(size)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
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
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }

            return MappedRegion(
                base: UnsafeRawPointer(ptr!),
                size: size
            )
        }
    }
}
