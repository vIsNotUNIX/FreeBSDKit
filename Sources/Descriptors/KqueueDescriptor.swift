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

/// A BSD descriptor representing a kqueue.
public protocol KqueueDescriptor: Descriptor, ~Copyable {
    /// Create a new kqueue descriptor.
    static func makeKqueue() throws -> Self

    /// Perform a kevent operation.
    ///
    /// - Parameters:
    ///   - changes: Events to register (add/modify/delete).
    ///   - maxEvents: Maximum number of events to return.
    ///   - timeout: Optional timeout for waiting; `nil` waits indefinitely.
    ///
    /// - Returns: A tuple of (number of returned events, array of returned kevent)
    func kevent(
        changes: [kevent],
        maxEvents: Int,
        timeout: TimeInterval?
    ) throws -> (Int, [kevent])
}

// The Glibc doesn't understand the difference between the struct kevent and the function call.
@_silgen_name("kevent")
func _kevent_c(
    _ kq: Int32,
    _ changelist: UnsafePointer<kevent>?,
    _ nchanges: Int32,
    _ eventlist: UnsafeMutablePointer<kevent>?,
    _ nevents: Int32,
    _ timeout: UnsafePointer<timespec>?
) -> Int32

// TODO: Refactor this.
public extension KqueueDescriptor where Self: ~Copyable {

    static func makeKqueue() throws -> Self {
        let raw = Glibc.kqueue()
        guard raw >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        return Self(raw)
    }

    func kevent(
        changes: [kevent],
        maxEvents: Int,
        timeout: TimeInterval?
    ) throws -> (Int, [kevent]) {

        var events = Array<kevent>(unsafeUninitializedCapacity: maxEvents) { buf, count in
            count = 0
        }

        var ts: timespec?
        if let timeout = timeout {
            let sec = Int(timeout)
            let nsec = Int((timeout - Double(sec)) * 1_000_000_000)
            ts = timespec(tv_sec: off_t(sec), tv_nsec: nsec)
        }

        let count = try self.unsafe { fd in
            let result = events.withUnsafeMutableBufferPointer { evBuf in
                changes.withUnsafeBufferPointer { chBuf in
                    _kevent_c(
                        fd,
                        chBuf.baseAddress,
                        Int32(chBuf.count),
                        evBuf.baseAddress,
                        Int32(maxEvents),
                        ts != nil ? withUnsafePointer(to: &ts!) { $0 } : nil
                    )
                }
            }

            guard result >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return Int(result)
        }

        let returnedEvents = Array(events.prefix(count))
        return (count, returnedEvents)
    }
}