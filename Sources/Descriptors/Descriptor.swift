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

/// A protocol representing a generic BSD descriptor resource, such as a file descriptor,
/// socket, kqueue, or process descriptor.
///
/// `Descriptor` extends `BSDResource` with a few properties and behaviors common to
/// all descriptors:
/// - They have an underlying raw BSD resource (`Int32`).
/// - They can be closed to release the resource.
/// - They can be sent across concurrency domains (`Sendable`).
///
/// Conforming types should provide an initializer from the raw descriptor and implement
/// proper cleanup via `close()`.
public protocol Descriptor: BSDResource, Sendable, ~Copyable
where RAWBSD == Int32 {
    /// Initializes the descriptor from a raw `Int32` resource.
    ///
    /// - Parameter value: The raw BSD descriptor.
    init(_ value: RAWBSD)

    /// Consumes the descriptor and closes/releases the underlying resource.
    ///
    /// After calling this method, the descriptor should no longer be used.
    consuming func close()
    // func duplicate() -> Self
    // func fstat() throws -> stat     // metadata via fstat(2)
    // func getFlags() throws -> Int32  // fcntl(F_GETFL)
    // func setFlags(_ flags: Int32) throws // fcntl(F_SETFL)
    // func setCloseOnExec(_ enabled: Bool) throws // fcntl(F_SETFD/FD_CLOEXEC)
    // func getCloseOnExec() throws -> Bool      // fcntl(F_GETFD)
}