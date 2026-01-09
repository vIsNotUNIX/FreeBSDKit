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

/// Options for shared memory mapping protection
public struct ShmProtection: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Readable memory (PROT_READ)
    public static let read  = ShmProtection(rawValue: PROT_READ)

    /// Writable memory (PROT_WRITE)
    public static let write = ShmProtection(rawValue: PROT_WRITE)

    /// Executable memory (PROT_EXEC)
    public static let exec  = ShmProtection(rawValue: PROT_EXEC)
}

/// A descriptor representing a POSIX shared memory object.
public protocol SharedMemoryDescriptor: Descriptor, ~Copyable {

    /// Open or create a POSIX shared memory object.
    ///
    /// - Parameters:
    ///   - name: A name beginning with `/` identifying the object.
    ///   - oflag: Flags such as `O_CREAT`|`O_RDWR`.
    ///   - mode: Permissions (e.g. `0o600`).
    static func open(
        name: String,
        oflag: Int32,
        mode: mode_t
    ) throws -> Self
    // TODO: OptionSet the flags

    /// Unlink (remove) the shared memory object name.
    static func unlink(name: String) throws

    /// Set the size of the shared object (must be done before mapping).
    func setSize(_ size: Int) throws

    /// Map the shared memory with given protection flags.
    ///
    /// Returns a pointer that must not be mutated if `prot` does not include `.write`.
    func map(
        size: Int,
        prot: ShmProtection,
        flags: Int32 
    ) throws -> UnsafeRawPointer // TODO: OptionSet the flags

    /// Unmap a previously mapped region.
    func unmap(_ pointer: UnsafeRawPointer, size: Int) throws
}

public extension SharedMemoryDescriptor where Self: ~Copyable {
    // TODO: OptionSet the flags.
    static func open(
        name: String,
        oflag: Int32,
        mode: mode_t
    ) throws -> Self {
        let rawFD = name.withCString { ptr in
            Glibc.shm_open(ptr, oflag, mode)
        }
        guard rawFD >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        return Self(rawFD)
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
    // TODO: OptionSet the flags
    func map(
        size: Int,
        prot: ShmProtection,
        flags: Int32
    ) throws -> UnsafeRawPointer {
        return try self.unsafe { fd in
            let ptr = Glibc.mmap(
                nil,
                size,
                prot.rawValue,
                flags,
                fd,
                0
            )
            guard ptr != MAP_FAILED else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return UnsafeRawPointer(ptr!)
        }
    }

    // Same here an enum would be better than raw pointers.
    func unmap(_ pointer: UnsafeRawPointer, size: Int) throws {
        let res = Glibc.munmap(UnsafeMutableRawPointer(mutating: pointer), size)
        guard res == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
    }
}