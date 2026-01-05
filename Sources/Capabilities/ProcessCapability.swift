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

import CProcessDescriptor
import Descriptors
import Foundation
import FreeBSDKit
import Glibc

/// Represents a BSD process descriptor.
struct ProcessCapability: Capability, ProcessDescriptor, ~Copyable {
    public typealias RAWBSD = Int32
    private var fd: RAWBSD

    init(_ fd: RAWBSD) { self.fd = fd }

    deinit {
        if fd >= 0 { Glibc.close(fd) }
    }

    consuming func close() {
        if fd >= 0 { Glibc.close(fd); fd = -1 }
    }

    consuming func take() -> RAWBSD {
        let raw = fd
        fd = -1
        return raw
    }

    func unsafe<R>(_ block: (RAWBSD) throws -> R) rethrows -> R {
        return try block(fd)
    }

    /// Forks a new process.
    ///
    /// - Returns: `ProcessDescriptorForkResult` containing:
    ///   - `Optional<descriptor>`: ProcessDescriptor for child (parent sees child descriptor, child sees nil)
    ///   - `isChild`: Bool indicating if the current context is child process
    static func fork(flags: ProcessDescriptorFlags = []) throws -> ProcessDescriptorForkResult {
        var fd: Int32 = 0
        let pid = pdfork(&fd, flags.rawValue)
        guard pid >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }

        if pid == 0 {
            // We are in the child
            return ProcessDescriptorForkResult(descriptor: nil, isChild: true)
        } else {
            // We are in the parent
            return ProcessDescriptorForkResult(descriptor: ProcessCapability(fd), isChild: false)
        }
    }

    /// Wait for the process to exit.
    func wait() throws -> Int32 {
        let pid = try pid()
        var status: Int32 = 0
        let ret = Glibc.waitpid(pid, &status, 0)
        guard ret >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return status
    }

    /// Send a signal to the process
    func kill(signal: ProcessSignal) throws {
        guard pdkill(fd, signal.rawValue) >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
    }

    /// Get the PID of the process
    func pid() throws -> pid_t {
        var pid: pid_t = 0
        let ret = pdgetpid(fd, &pid)
        guard ret >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return pid
    }
}