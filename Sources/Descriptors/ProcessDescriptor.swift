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
import Glibc
import Foundation
import FreeBSDKit

/// BSD process descriptor flags.
public struct ProcessDescriptorFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let pdwait    = ProcessDescriptorFlags(rawValue: 0x01)
    public static let pdtraced  = ProcessDescriptorFlags(rawValue: 0x02)
    public static let pdnowait  = ProcessDescriptorFlags(rawValue: 0x04)
}

public struct ProcessDescriptorForkResult: ~Copyable {
    public let descriptor: (any ProcessDescriptor & ~Copyable)?
    public let isChild: Bool

    public init(descriptor: consuming (any ProcessDescriptor & ~Copyable)?, isChild: Bool) {
        self.descriptor = descriptor
        self.isChild = isChild
    }
}

public protocol ProcessDescriptor: Descriptor, ~Copyable {
    static func fork(flags: ProcessDescriptorFlags) throws -> ProcessDescriptorForkResult
    func wait() throws -> Int32
    func kill(signal: BSDSignal) throws
    func pid() throws -> pid_t
}

extension ProcessDescriptor where Self: ~Copyable {
    public static func fork(flags: ProcessDescriptorFlags = []) throws -> ProcessDescriptorForkResult {
        var fd: Int32 = 0
        let pid = pdfork(&fd, flags.rawValue)
        guard pid >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }

        if pid == 0 {
            // We are in the child
            return ProcessDescriptorForkResult(descriptor: nil, isChild: true)
        } else {
            // We are in the parent
            return ProcessDescriptorForkResult(descriptor: Self(fd), isChild: false)
        }
    }
    // TODO
    /// Wait for the process to exit
    public func wait() throws -> Int32 {
        let pid = try self.pid()
        var status: Int32 = 0
        let ret = Glibc.waitpid(pid, &status, 0)
        guard ret >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return status
    }

    /// Send a signal to the process
    public func kill(signal: BSDSignal) throws {
        try self.unsafe { fd in
            guard pdkill(fd, signal.rawValue) >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    /// Get the PID of the process
    public func pid() throws -> pid_t {
        try self.unsafe { fd in
            var pid: pid_t = 0
            let ret = pdgetpid(fd, &pid)
            guard ret >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
            return pid
        }
    }
}
