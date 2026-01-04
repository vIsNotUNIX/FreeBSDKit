import CProcessDescriptor
import Glibc
import Foundation
import FreeBSDKit

/// BSD process descriptor flags.
public struct ProcessFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let pdwait    = ProcessFlags(rawValue: 0x01)
    public static let pdtraced  = ProcessFlags(rawValue: 0x02)
    public static let pdnowait  = ProcessFlags(rawValue: 0x04)
}

public struct ForkResult: ~Copyable {
    let descriptor: ProcessDescriptor?
    let isChild: Bool
}

/// Represents a BSD process descriptor.
struct ProcessDescriptor: Capability, ~Copyable {
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
    /// - Returns: Tuple containing:
    ///   - `Optional<descriptor>`: ProcessDescriptor for child (parent sees child descriptor, child sees nil)
    ///   - `isChild`: Bool indicating if the current context is child process
    static func fork(flags: ProcessFlags = []) throws -> ForkResult {
        var fd: Int32 = 0
        let pid = pdfork(&fd, flags.rawValue)
        guard pid >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }

        if pid == 0 {
            // We are in the child
            return ForkResult(descriptor: nil, isChild: true)
        } else {
            // We are in the parent
            return ForkResult(descriptor: ProcessDescriptor(fd), isChild: false)
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