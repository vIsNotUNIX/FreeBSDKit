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

import Foundation
import FreeBSDKit
import CEventDescriptor

/// Flags passed to eventfd().
public struct EventFDFlags: OptionSet {
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
