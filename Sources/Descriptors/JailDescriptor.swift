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
 
import CJails
import Glibc
import Foundation
import FreeBSDKit

// MARK: - Jail Flags

public struct JailSetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let create     = JailSetFlags(rawValue: JAIL_CREATE)
    public static let update     = JailSetFlags(rawValue: JAIL_UPDATE)
    public static let attach     = JailSetFlags(rawValue: JAIL_ATTACH)

    public static let useDesc    = JailSetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc     = JailSetFlags(rawValue: JAIL_AT_DESC)

    public static let getDesc    = JailSetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc    = JailSetFlags(rawValue: JAIL_OWN_DESC)
}

public struct JailGetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let dying      = JailGetFlags(rawValue: JAIL_DYING)
    public static let useDesc    = JailGetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc     = JailGetFlags(rawValue: JAIL_AT_DESC)
    public static let getDesc    = JailGetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc    = JailGetFlags(rawValue: JAIL_OWN_DESC)
}

// MARK: - Jail Descriptor Protocol

/// A descriptor representing a FreeBSD jail.
///
/// This is a *capability handle* to a jail. Once obtained, no JID is required.
public protocol JailDescriptor: Descriptor, ~Copyable {

    /// Attach the current process to the jail.
    func attach() throws

    /// Remove the jail.
    ///
    /// For owning descriptors this is optional; closing the descriptor
    /// will implicitly remove the jail.
    func remove() throws
}

// MARK: - Default Implementations

public extension JailDescriptor where Self: ~Copyable {

    func attach() throws {
        try self.unsafe { fd in
            guard jail_attach_jd(fd) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    func remove() throws {
        try self.unsafe { fd in
            guard jail_remove_jd(fd) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }
}

// MARK: - Concrete Jail Descriptor

/// Concrete jail descriptor.
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

    public func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

// MARK: - Jail Creation / Lookup

public enum Jail {

    /// Create or update a jail and return a descriptor.
    ///
    /// You must supply an iovec describing jail parameters.
    /// The descriptor returned may be owning or borrowed depending on flags.
    public static func set(
        iov: UnsafeMutablePointer<iovec>,
        count: Int,
        flags: JailSetFlags
    ) throws -> SystemJailDescriptor {

        let jid = jail_set(iov, UInt32(count), flags.rawValue)
        guard jid >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }

        // Kernel writes descriptor into `desc` iovec entry
        // Caller is responsible for including it.
        let descFD = extractDescFD(from: iov, count: count)
        return SystemJailDescriptor(descFD)
    }

    /// Lookup a jail and return a descriptor.
    public static func get(
        iov: UnsafeMutablePointer<iovec>,
        count: Int,
        flags: JailGetFlags
    ) throws -> SystemJailDescriptor {

        let jid = jail_get(iov, UInt32(count), flags.rawValue)
        guard jid >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }

        let descFD = extractDescFD(from: iov, count: count)
        return SystemJailDescriptor(descFD)
    }

    // MARK: - Helper

    private static func extractDescFD(
        from iov: UnsafeMutablePointer<iovec>,
        count: Int
    ) -> Int32 {

        for i in 0..<count {
            let entry = iov.advanced(by: i).pointee
            if let base = entry.iov_base,
               entry.iov_len == MemoryLayout<Int32>.size {

                return base.assumingMemoryBound(to: Int32.self).pointee
            }
        }
        fatalError("jail descriptor not returned by kernel")
    }
}