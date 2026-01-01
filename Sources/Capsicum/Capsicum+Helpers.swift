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

/// Utilities for interacting with Capsicum sandbox helpers (`<capsicum_helpers>`).
/// 
/// These functions provide safe Swift wrappers around the Capsicum Casper API.
/// Most functions throw a `CapsicumError` if the underlying C call fails.
extension Capsicum {

    /// Enter Casper mode, restricting the process to Capsicum sandbox helpers.
    ///
    /// - Throws: `CapsicumError.casperUnsupported` if Casper is not available,
    ///           or another `CapsicumError` if the underlying call fails.
    public static func enterCasper() throws {
        guard caph_enter_casper() == 0 else {
            throw CapsicumError.errorFromErrno(errno, isCasper: true)
        }
    }

    /// Restricts a stream (file descriptor) according to the specified options.
    ///
    /// - Parameters:
    ///   - fd: The file descriptor to restrict.
    ///   - options: Options specifying which operations are allowed (`StreamLimitOptions`).
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitStream(fd: Int32, options: StreamLimitOptions) throws {
        guard caph_limit_stream(fd, options.rawValue) == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts standard input (stdin) for the process.
    ///
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitStdin() throws {
        guard caph_limit_stdin() == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts standard error (stderr) for the process.
    ///
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitStderr() throws {
        guard caph_limit_stderr() == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts standard output (stdout) for the process.
    ///
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitStdout() throws {
        guard caph_limit_stdout() == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Restricts all standard I/O streams (stdin, stdout, stderr) for the process.
    ///
    /// - Throws: `CapsicumError` if the underlying call fails.
    public static func limitStdio() throws {
        guard caph_limit_stdio() == 0 else {
            throw CapsicumError.errorFromErrno(errno)
        }
    }

    /// Cache timezone data in memory for faster access.
    ///
    /// This call is informational and does not throw.
    public static func cacheTZData() {
        caph_cache_tzdata()
    }

    /// Cache "cat" man pages in memory for faster access.
    ///
    /// This call is informational and does not throw.
    public static func cacheCatPages() {
        caph_cache_catpages()
    }
}