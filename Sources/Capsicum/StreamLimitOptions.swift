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

import CCapsicum
import Glibc

/// Options for restricting permitted operations on a stream (file descriptor) in Capsicum.
///
/// `StreamLimitOptions` is used with `Capsicum.limitStream(fd:options:)` to
/// specify which operations are allowed on a given file descriptor.
public struct StreamLimitOptions: OptionSet {
    public let rawValue: Int32

    /// Creates a new `StreamLimitOptions` from the raw value.
    ///
    /// - Parameter rawValue: The raw `Int32` value representing the options.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    // MARK: - Standard Options

    /// Ignore `EBADF` (bad file descriptor) errors on this stream.
    ///
    /// Use this if you want Capsicum to silently ignore invalid file descriptors.
    public static let ignoreBadFileDescriptor =
        StreamLimitOptions(rawValue: CAPH_IGNORE_EBADF)

    /// Allow reading from the stream.
    public static let read =
        StreamLimitOptions(rawValue: CAPH_READ)

    /// Allow writing to the stream.
    public static let write =
        StreamLimitOptions(rawValue: CAPH_WRITE)
}

