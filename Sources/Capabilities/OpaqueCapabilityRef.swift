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
import Descriptors

/// Capability-aware opaque descriptor.
public final class CapableOpaqueDescriptorRef: OpaqueDescriptorRef, @unchecked Sendable {

    private var _capable: Bool
    private let capLock = NSLock()

    public init(_ fd: Int32, kind: DescriptorKind, capable: Bool = true) {
        self._capable = capable
        super.init(fd, kind: kind)
    }

    /// Indicates whether this descriptor is considered Capsicum-capable.
    public var capable: Bool {
        get {
            capLock.lock()
            defer { capLock.unlock() }
            return _capable
        }
        set {
            capLock.lock()
            _capable = newValue
            capLock.unlock()
        }
    }

    public override var debugDescription: String {
        capLock.lock()
        let capable = _capable
        capLock.unlock()
        return "\(super.debugDescription), capable: \(capable)"
    }
}