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

// MARK: - Base Opaque Descriptor

/// Type-erased, reference-counted BSD file descriptor.
///
/// This class provides:
/// - Thread-safe access
/// - Reference-counted lifetime
/// - Deterministic `close(2)` on deinit
///
/// It intentionally has **no capability semantics**.
/// Those are layered in subclasses.
open class OpaqueDescriptorRef: CustomDebugStringConvertible, @unchecked Sendable {

    private var fd: Int32?
    private var _kind: DescriptorKind = .unknown
    private let lock = NSLock()

    // MARK: - Initializers

    public init(_ value: Int32) {
        self.fd = value
    }

    public init(_ fd: Int32, kind: DescriptorKind) {
        self.fd = fd
        self._kind = kind
    }

    // MARK: - Descriptor Metadata

    public var kind: DescriptorKind {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _kind
        }
        set {
            lock.lock()
            _kind = newValue
            lock.unlock()
        }
    }

    // MARK: - Raw FD Access

    /// Return the underlying BSD descriptor, if still valid.
    ///
    /// This is intentionally **optional** to reflect lifetime.
    func toBSDValue() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        return fd
    }

    // MARK: - Deinitialization

    deinit {
        lock.lock()
        if let desc = fd {
            Glibc.close(desc)
            fd = nil
        }
        lock.unlock()
    }

    // MARK: - Debugging

    open var debugDescription: String {
        lock.lock()
        let desc = fd ?? -1
        let kind = _kind
        lock.unlock()
        return "OpaqueDescriptorRef(kind: \(kind), fd: \(desc))"
    }
}