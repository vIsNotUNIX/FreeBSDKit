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

// MARK: - Flags

/// Flags accepted by `pdfork(2)`
public struct ProcessDescriptorFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Allow the process to live after the last descriptor is closed.
    /// Not permitted in Capsicum capability mode.
    public static let daemon  = ProcessDescriptorFlags(rawValue: PD_DAEMON)

    /// Set close-on-exec on the process descriptor.
    public static let cloExec = ProcessDescriptorFlags(rawValue: PD_CLOEXEC)
}

// MARK: - Exit Status

/// Decoded process termination state.
public enum ProcessExitStatus: Sendable {
    case exited(code: Int32)

    case signaled(
        signal: BSDSignal?,
        rawSignal: Int32,
        coreDumped: Bool
    )

    case stopped(
        signal: BSDSignal?,
        rawSignal: Int32
    )
}

// MARK: - Fork Result

/// Result of `pdfork(2)`
public struct ProcessDescriptorForkResult: ~Copyable {
    /// Present only in the parent.
    public let descriptor: (any ProcessDescriptor & ~Copyable)?
    public let isChild: Bool

    public init(
        descriptor: consuming (any ProcessDescriptor & ~Copyable)?,
        isChild: Bool
    ) {
        self.descriptor = descriptor
        self.isChild = isChild
    }
}

// MARK: - Protocol

/// Capability-oriented handle to a process.
public protocol ProcessDescriptor: Descriptor, ~Copyable {

    /// Create a process descriptor using `pdfork(2)`.
    static func fork(flags: ProcessDescriptorFlags) throws -> ProcessDescriptorForkResult

    /// Wait for the process to exit.
    ///
    /// Implemented via `pdgetpid(2)` + `wait4(2)`.
    func wait() throws -> ProcessExitStatus

    /// Send a signal using `pdkill(2)`.
    func kill(signal: BSDSignal) throws

    /// Query the underlying PID (escape hatch).
    func pid() throws -> pid_t
}

// MARK: - Implementation

public extension ProcessDescriptor where Self: ~Copyable {

    static func fork(
        flags: ProcessDescriptorFlags = []
    ) throws -> ProcessDescriptorForkResult {

        var fd: Int32 = -1
        let pid = pdfork(&fd, flags.rawValue)

        guard pid >= 0 else {
            throw  BSDError.throwErrno(errno)
        }

        if pid == 0 {
            // Child: no descriptor
            return ProcessDescriptorForkResult(
                descriptor: nil,
                isChild: true
            )
        }

        // Parent: owns the process descriptor
        return ProcessDescriptorForkResult(
            descriptor: Self(fd),
            isChild: false
        )
    }

    func wait() throws -> ProcessExitStatus {
        let pid = try self.pid()

        var status: Int32 = 0
        var rusage = rusage()

        let ret = wait4(pid, &status, 0, &rusage)
        guard ret >= 0 else {
            throw  BSDError.throwErrno(errno)
        }

        return decodeWaitStatus(status)
    }

    func kill(signal: BSDSignal) throws {
        try self.unsafe { fd in
            guard pdkill(fd, signal.rawValue) == 0 else {
                throw  BSDError.throwErrno(errno)
            }
        }
    }

    func pid() throws -> pid_t {
        try self.unsafe { fd in
            var pid: pid_t = 0
            guard pdgetpid(fd, &pid) == 0 else {
                throw  BSDError.throwErrno(errno)
            }
            return pid
        }
    }
}

// Wait Status Decoding
@inline(__always)
private func decodeWaitStatus(_ status: Int32) -> ProcessExitStatus {
    let exitCode = (status >> 8) & 0xff
    let sig      = status & 0x7f
    let core     = (status & 0x80) != 0

    // Normal exit
    if sig == 0 {
        return .exited(code: exitCode)
    }

    // Stopped (SIGSTOP / SIGTSTP / etc.)
    if sig == 0x7f {
        let raw = exitCode
        return .stopped(
            signal: BSDSignal(rawValue: raw),
            rawSignal: raw
        )
    }

    // Signaled
    return .signaled(
        signal: BSDSignal(rawValue: sig),
        rawSignal: sig,
        coreDumped: core
    )
}