/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Predefined Scripts

extension DScript {
    /// Creates a syscall counting script.
    ///
    /// Counts all syscalls grouped by function name, optionally filtered to
    /// specific processes.
    ///
    /// ```swift
    /// // Count all syscalls system-wide
    /// let script = DScript.syscallCounts()
    ///
    /// // Count syscalls for a specific process
    /// let script = DScript.syscallCounts(for: .execname("nginx"))
    /// ```
    public static func syscallCounts(for target: DTraceTarget = .all) -> DScript {
        DScript {
            Probe("syscall:freebsd::entry") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Count(by: "probefunc")
            }
        }
    }

    /// Creates a file open tracing script.
    ///
    /// Prints each file open with the process name and path.
    ///
    /// ```swift
    /// let script = DScript.fileOpens(for: .execname("myapp"))
    /// ```
    public static func fileOpens(for target: DTraceTarget = .all) -> DScript {
        DScript {
            Probe("syscall:freebsd:open*:entry") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s: %s", "execname", "copyinstr(arg0)")
            }
        }
    }

    /// Creates a CPU profiling script.
    ///
    /// Samples at the specified frequency and counts by process name.
    ///
    /// - Parameter hz: Sampling frequency in Hz (default: 997, a prime to avoid aliasing).
    /// - Parameter target: Process filter (default: all).
    ///
    /// ```swift
    /// let script = DScript.cpuProfile(hz: 99, for: .execname("myapp"))
    /// ```
    public static func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) -> DScript {
        DScript {
            Probe("profile-\(hz)") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Count(by: "execname")
            }
        }
    }

    /// Creates a process exec tracing script.
    ///
    /// Prints when any process successfully execs a new program.
    ///
    /// ```swift
    /// let script = DScript.processExec()
    /// ```
    public static func processExec() -> DScript {
        DScript {
            Probe("proc:::exec-success") {
                Printf("%s[%d] exec'd %s", "execname", "pid", "curpsinfo->pr_psargs")
            }
        }
    }

    /// Creates an I/O bytes tracking script.
    ///
    /// Sums bytes read and written by process name.
    ///
    /// ```swift
    /// let script = DScript.ioBytes(for: .execname("nginx"))
    /// ```
    public static func ioBytes(for target: DTraceTarget = .all) -> DScript {
        DScript {
            Probe("syscall:freebsd:read:return") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                When("arg0 > 0")
                Sum("arg0", by: "execname")
            }
            Probe("syscall:freebsd:write:return") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                When("arg0 > 0")
                Sum("arg0", by: "execname")
            }
        }
    }

    /// Creates a syscall latency measurement script.
    ///
    /// Measures the time spent in a specific syscall and creates a histogram.
    ///
    /// ```swift
    /// let script = DScript.syscallLatency("read", for: .execname("nginx"))
    /// ```
    public static func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) -> DScript {
        DScript {
            Probe("syscall:freebsd:\(syscall):entry") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Timestamp()
            }
            Probe("syscall:freebsd:\(syscall):return") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                When("self->ts")
                Latency(by: "execname")
            }
        }
    }
}
