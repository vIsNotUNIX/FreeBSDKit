/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// Standard BSD signals.
///
/// Signal numbers are specific to FreeBSD.
public enum BSDSignal: Int32, Hashable, Sendable {
    case hup    = 1      // hangup
    case int    = 2      // interrupt
    case quit   = 3      // quit
    case ill    = 4      // illegal instruction
    case trap   = 5      // trace trap
    case abrt   = 6      // abort()
    case emt    = 7      // EMT instruction (FreeBSD-specific)
    case fpe    = 8      // floating point exception
    case kill   = 9      // kill (non-catchable)
    case bus    = 10     // bus error
    case segv   = 11     // segmentation violation
    case sys    = 12     // bad system call
    case pipe   = 13     // broken pipe
    case alrm   = 14     // alarm clock
    case term   = 15     // software termination
    case urg    = 16     // urgent condition on IO channel
    case stop   = 17     // sendable stop (non-catchable)
    case tstp   = 18     // stop from tty
    case cont   = 19     // continue a stopped process
    case chld   = 20     // child stopped or exited
    case ttin   = 21     // background tty read
    case ttou   = 22     // background tty write
    case io     = 23     // input/output possible
    case xcpu   = 24     // exceeded CPU time limit
    case xfsz   = 25     // exceeded file size limit
    case vtAlrm = 26     // virtual time alarm
    case prof   = 27     // profiling time alarm
    case winch  = 28     // window size changes
    case info   = 29     // information request (FreeBSD-specific)
    case usr1   = 30     // user defined signal 1
    case usr2   = 31     // user defined signal 2

    /// Whether this signal can be caught or ignored.
    ///
    /// SIGKILL and SIGSTOP cannot be caught, blocked, or ignored.
    public var isCatchable: Bool {
        switch self {
        case .kill, .stop:
            return false
        default:
            return true
        }
    }
}

extension BSDSignal: CustomStringConvertible {
    public var description: String {
        switch self {
        case .hup:    return "SIGHUP"
        case .int:    return "SIGINT"
        case .quit:   return "SIGQUIT"
        case .ill:    return "SIGILL"
        case .trap:   return "SIGTRAP"
        case .abrt:   return "SIGABRT"
        case .emt:    return "SIGEMT"
        case .fpe:    return "SIGFPE"
        case .kill:   return "SIGKILL"
        case .bus:    return "SIGBUS"
        case .segv:   return "SIGSEGV"
        case .sys:    return "SIGSYS"
        case .pipe:   return "SIGPIPE"
        case .alrm:   return "SIGALRM"
        case .term:   return "SIGTERM"
        case .urg:    return "SIGURG"
        case .stop:   return "SIGSTOP"
        case .tstp:   return "SIGTSTP"
        case .cont:   return "SIGCONT"
        case .chld:   return "SIGCHLD"
        case .ttin:   return "SIGTTIN"
        case .ttou:   return "SIGTTOU"
        case .io:     return "SIGIO"
        case .xcpu:   return "SIGXCPU"
        case .xfsz:   return "SIGXFSZ"
        case .vtAlrm: return "SIGVTALRM"
        case .prof:   return "SIGPROF"
        case .winch:  return "SIGWINCH"
        case .info:   return "SIGINFO"
        case .usr1:   return "SIGUSR1"
        case .usr2:   return "SIGUSR2"
        }
    }
}