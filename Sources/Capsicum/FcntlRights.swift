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

/// A set of flags representing the fcntl commands that may be
/// permitted on a file descriptor when using Capsicum’s fcntl limits.
public struct FcntlRights: OptionSet {
    public let rawValue: UInt32

    /// Permits the `F_GETFL` fcntl command.
    public static let getFlags = FcntlRights(rawValue: UInt32(CAP_FCNTL_GETFL))

    /// Permits the `F_SETFL` fcntl command.
    public static let setFlags = FcntlRights(rawValue: UInt32(CAP_FCNTL_SETFL))

    /// Permits the `F_GETOWN` fcntl command.
    public static let getOwner = FcntlRights(rawValue: UInt32(CAP_FCNTL_GETOWN))

    /// Permits the `F_SETOWN` fcntl command.
    public static let setOwner = FcntlRights(rawValue: UInt32(CAP_FCNTL_SETOWN))

    /// Creates a new set of fcntl rights from a raw bitmask.
    ///
    /// - Parameter rawValue: A bitmask of fcntl rights.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}