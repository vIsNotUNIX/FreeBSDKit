/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */
 
import CProcessDescriptor
import Glibc
import Foundation
import FreeBSDKit

// MARK: - Flags

/// Flags accepted by `pdfork(2)`
public struct ProcessDescriptorFlags: OptionSet, Sendable {
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

/// Capability-oriented handle to a process.
public protocol ProcessDescriptor: Descriptor, ~Copyable {

    /// Create a process descriptor using `pdfork(2)`.
    static func fork(flags: ProcessDescriptorFlags) throws -> ProcessDescriptorForkResult

    /// Wait for the process to exit.
    ///
    /// Uses kqueue with EVFILT_PROCDESC to monitor process state, then collects
    /// exit status via wait4(). This is the proper way to wait on process descriptors,
    /// avoiding PID-reuse races while still obtaining resource usage and exit status.
    func wait() throws -> ProcessExitStatus

    /// Send a signal using `pdkill(2)`.
    func kill(signal: BSDSignal) throws

    /// Query the underlying PID (escape hatch).
    func pid() throws -> pid_t
}

public extension ProcessDescriptor where Self: ~Copyable {

    static func fork(
        flags: ProcessDescriptorFlags = []
    ) throws -> ProcessDescriptorForkResult {

        var fd: Int32 = -1
        let pid = pdfork(&fd, flags.rawValue)

        guard pid >= 0 else {
            try BSDError.throwErrno(errno)
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
        try self.unsafe { fd in
            // Create a kqueue for monitoring the process descriptor
            let kq = Glibc.kqueue()
            guard kq >= 0 else {
                try BSDError.throwErrno(errno)
            }
            defer { _ = Glibc.close(kq) }

            // Register EVFILT_PROCDESC to monitor process exit
            var kev = Glibc.kevent()
            kev.ident = UInt(bitPattern: Int(fd))
            kev.filter = Int16(EVFILT_PROCDESC)
            kev.flags = UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT)
            kev.fflags = UInt32(NOTE_EXIT)
            kev.data = 0
            kev.udata = nil

            var events = Array<Glibc.kevent>(repeating: Glibc.kevent(), count: 1)

            // Register the event and wait for process exit
            let n = events.withUnsafeMutableBufferPointer { evBuf in
                withUnsafePointer(to: &kev) { kevPtr in
                    _kevent_c(kq, kevPtr, 1, evBuf.baseAddress, 1, nil)
                }
            }

            guard n >= 0 else {
                try BSDError.throwErrno(errno)
            }

            // Process has exited, now collect its status via wait4()
            // We still need the PID for wait4(), but the kqueue ensured
            // we only call it after the process actually exited
            var pid: pid_t = 0
            guard pdgetpid(fd, &pid) == 0 else {
                try BSDError.throwErrno(errno)
            }

            var status: Int32 = 0
            var rusage = rusage()

            let ret = wait4(pid, &status, 0, &rusage)
            guard ret >= 0 else {
                try BSDError.throwErrno(errno)
            }

            return decodeWaitStatus(status)
        }
    }

    func kill(signal: BSDSignal) throws {
        try self.unsafe { fd in
            guard pdkill(fd, signal.rawValue) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func pid() throws -> pid_t {
        try self.unsafe { fd in
            var pid: pid_t = 0
            guard pdgetpid(fd, &pid) == 0 else {
                try BSDError.throwErrno(errno)
            }
            return pid
        }
    }
}

// Wait Status Decoding
//
// Uses the standard FreeBSD wait(2) status macros via C helpers.
// DO NOT manually decode status with bit shifts - the encoding is OS-specific
// and not guaranteed to remain stable across BSD variants.
@inline(__always)
private func decodeWaitStatus(_ status: Int32) -> ProcessExitStatus {
    // Check if process exited normally
    if cwait_wifexited(status) {
        let code = cwait_wexitstatus(status)
        return .exited(code: code)
    }

    // Check if process was terminated by a signal
    if cwait_wifsignaled(status) {
        let signum = cwait_wtermsig(status)
        let core = cwait_wcoredump(status)
        return .signaled(
            signal: BSDSignal(rawValue: signum),
            rawSignal: signum,
            coreDumped: core
        )
    }

    // Check if process was stopped
    if cwait_wifstopped(status) {
        let signum = cwait_wstopsig(status)
        return .stopped(
            signal: BSDSignal(rawValue: signum),
            rawSignal: signum
        )
    }

    // Fallback for unknown status (should not happen)
    return .exited(code: -1)
}