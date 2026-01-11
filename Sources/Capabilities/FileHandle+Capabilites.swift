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
import Capsicum

public extension FileHandle {

    /// Apply Capsicum rights to this file handle.
    /// Returns `true` if the rights were applied, `false` on failure.
    func applyCapsicumRights(_ rights: CapsicumRightSet) -> Bool {
        return CapsicumRights.limit(fd: fileDescriptor, rights: rights)
    }

    /// Restrict allowed stream operations.
    func limitCapsicumStream(options: StreamLimitOptions) throws {
        try CapsicumRights.limitStream(fd: fileDescriptor, options: options)
    }

    /// Restrict allowed ioctl commands.
    func limitCapsicumIoctls(_ commands: [IoctlCommand]) throws {
        try CapsicumRights.limitIoctls(fd: fileDescriptor, commands: commands)
    }

    /// Restrict allowed fcntl commands.
    func limitCapsicumFcntls(_ rights: FcntlRights) throws {
        try CapsicumRights.limitFcntls(fd: fileDescriptor, rights: rights)
    }
    /// Get the currently allowed ioctl commands.
    func getCapsicumIoctls(maxCount: Int = 32) throws -> [IoctlCommand] {
        try CapsicumRights.getIoctls(fd: fileDescriptor, maxCount: maxCount)
    }
    /// Get allowed fcntl commands mask.
    func getCapsicumFcntls() throws -> FcntlRights {
        try CapsicumRights.getFcntls(fd: fileDescriptor)
    }
}
