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

import Capsicum
import Descriptors
import FreeBSDKit
import Glibc


/// `Capability` inherits from `Descriptor`, meaning it represents a resource
/// with a raw `Int32` descriptor that can be closed and managed safely.
///
/// Conforming types indicate that the resource represents a **capability** in the
/// system — that is, a controlled access token to perform operations, rather than
/// just a raw descriptor. This is useful for enforcing capability-based security
/// patterns in your code.
///
/// Typically, types conforming to `Capability` are more restrictive or specialized
/// descriptors (e.g., `FileDescriptor`, `SocketDescriptor`, `KqueueDescriptor`),
/// providing safe operations in addition to the universal `close()` method.
public protocol Capability: Descriptor, ~Copyable {}

public extension Capability where Self: ~Copyable {

    func limit(rights: CapsicumRightSet) -> Bool {
        return self.unsafe { fd in
            CapsicumRights.limit(fd: fd, rights: rights)
        }
    }

    func limitStream(options: StreamLimitOptions) throws {
        try self.unsafe { fd in
            try CapsicumRights.limitStream(fd: fd, options: options)
        }
    }

    func limitIoctls(commands: [IoctlCommand]) throws {
        try self.unsafe { fd in
            try CapsicumRights.limitIoctls(fd: fd, commands: commands)
        }
    }

    func limitFcntls(rights: FcntlRights) throws {
        try self.unsafe { fd in
            try CapsicumRights.limitFcntls(fd: fd, rights: rights)
        }
    }

    func getIoctls(maxCount: Int = 32) throws -> [IoctlCommand] {
        return try self.unsafe { fd in
            try CapsicumRights.getIoctls(fd: fd, maxCount: maxCount)
        }
    }

    func getFcntls() throws -> FcntlRights {
        return try self.unsafe { fd in
            try CapsicumRights.getFcntls(fd: fd)
        }
    }
}
