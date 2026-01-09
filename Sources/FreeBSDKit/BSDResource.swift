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

/// A protocol representing a low-level BSD resource, such as a file descriptor or socket.
///
/// Types conforming to `BSDResource` provide access to the underlying raw BSD handle (`RAWBSD`)
/// while offering safe, Swift-friendly operations.
///
/// Conforming types can be `~Copyable` to ensure that ownership semantics are respected,
/// and the `take()` method provides a consuming way to extract the underlying resource.
public protocol BSDResource: ~Copyable {
    /// The type of the underlying raw BSD resource (e.g., `Int32` for file descriptors).
    associatedtype RAWBSD

    /// Consumes the conforming instance and returns the underlying raw BSD resource.
    ///
    /// - Returns: The raw BSD resource of type `RAWBSD`.
    consuming func take() -> RAWBSD

    /// Provides temporary access to the raw BSD resource for low-level operations.
    ///
    /// This method executes the given closure with the underlying resource as its argument.
    /// Any errors thrown inside the closure are propagated to the caller.
    ///
    /// - Parameter block: A closure that receives the raw BSD resource and can throw an error.
    /// - Returns: The result of the closure.
    /// - Throws: Any error thrown by the closure.
    ///
    /// - Warning: Tinkering with the internal state of the raw resource is generally unsafe
    ///   and may lead to undefined behavior. Prefer using higher-level abstractions.
    func unsafe<R>(_ block: (RAWBSD) throws -> R) rethrows -> R where R: ~Copyable
}