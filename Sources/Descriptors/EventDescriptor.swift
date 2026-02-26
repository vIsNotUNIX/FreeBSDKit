/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit
import CEventDescriptor

/// Flags passed to eventfd().
public struct EventFDFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Set FD_CLOEXEC
    public static let cloexec   = EventFDFlags(rawValue: EFD_CLOEXEC)
    /// Non-blocking read/write
    public static let nonblock  = EventFDFlags(rawValue: EFD_NONBLOCK)
    /// Read returns 1 and decrements (semaphore style)
    public static let semaphore = EventFDFlags(rawValue: EFD_SEMAPHORE)
}

/// An descriptor that supports eventfd semantics.
public protocol EventDescriptor: Descriptor, ~Copyable {
    /// Create a new eventfd object.
    static func eventfd(initValue: UInt32, flags: EventFDFlags) throws -> Self

    /// Write/notify the counter by value.
    func write(_ value: UInt64) throws

    /// Read/consume the counter according to eventfd semantics.
    func read() throws -> UInt64
}


public extension EventDescriptor where Self: ~Copyable {

    static func eventfd(initValue: UInt32, flags: EventFDFlags) throws -> Self {
        let fd = CEventDescriptor.eventfd(initValue, flags.rawValue)
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(fd)
    }

    func write(_ value: UInt64) throws {
        try self.unsafe { fd in
            guard eventfd_write(fd, value) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func read() throws -> UInt64 {
        var val: UInt64 = 0
        try self.unsafe { fd in
            guard eventfd_read(fd, &val) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
        return val
    }
}
