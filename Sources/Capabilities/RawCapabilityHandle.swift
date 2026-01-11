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
import Descriptors
import Foundation
import FreeBSDKit

// TODO: Make this a subclass of the OpaqueCapabilityHandle,
// moving the capability info here.
/// A reusable noncopyable owner of a raw Int32 descriptor.
public struct RawCapabilityHandle: Sendable, ~Copyable {
    fileprivate var fd: Int32

    /// Create from a raw descriptor.
    public init(_ raw: Int32) {
        self.fd = raw
    }

    /// Always close on destruction if not already closed.
    deinit {
        if fd >= 0 {
            Glibc.close(fd)
        }
    }

    /// Close the descriptor if it hasn’t been closed already.
    public consuming func close() {
        if fd >= 0 {
            Glibc.close(fd)
            fd = -1
        }
    }

    /// Take and return the raw descriptor, leaving this handle invalidated.
    public consuming func take() -> Int32 {
        let raw = fd
        fd = -1
        return raw
    }

    /// Temporarily borrow the raw descriptor for performing actions on it.
    public func unsafe<R>(_ body: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        return try body(fd)
    }
}
