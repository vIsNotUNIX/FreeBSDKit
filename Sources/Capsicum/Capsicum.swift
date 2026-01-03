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

/// A Swift interface to the FreeBSD Capsicum sandboxing API.
///
/// Capsicum is a capability and sandbox framework built into FreeBSD that
/// allows a process to restrict itself to a set of permitted operations
/// on file descriptors and in capability mode. After entering capability
/// mode, access to global system namespaces (like files by pathname)
/// is disabled and operations are restricted to those explicitly
/// permitted via rights limits.
public enum Capsicum: Sendable {

    // MARK: — Capability Mode

    /// Enters *Capsicum capability mode* for the current process.
    ///
    /// Once in capability mode, the process cannot access global namespaces
    /// such as the file system by path or the PID namespace. Only operations
    /// on file descriptors with appropriate rights remain permitted.
    ///
    /// - Throws: `CapsicumError.capsicumUnsupported` if Capsicum is unavailable.
    public static func enter() throws {
        guard cap_enter() == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
    }

    /// Determines whether the current process is already in capability mode.
    ///
    /// - Returns: `true` if capability mode is enabled, `false` otherwise.
    /// - Throws: `CapsicumError.capsicumUnsupported` if Capsicum is unavailable.
    public static func status() throws -> Bool {
        var mode: UInt32 = 0
        guard cap_getmode(&mode) == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
        return mode == 1
    }
}