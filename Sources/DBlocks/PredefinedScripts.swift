/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Predefined Scripts

extension DBlocks {
    /// Creates a syscall counting script.
    ///
    /// Counts all syscalls grouped by function name, optionally filtered to
    /// specific processes.
    ///
    /// ```swift
    /// // Count all syscalls system-wide
    /// let script = DBlocks.syscallCounts()
    ///
    /// // Count syscalls for a specific process
    /// let script = DBlocks.syscallCounts(for: .execname("nginx"))
    /// ```
    public static func syscallCounts(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
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
    /// let script = DBlocks.fileOpens(for: .execname("myapp"))
    /// ```
    public static func fileOpens(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
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
    /// let script = DBlocks.cpuProfile(hz: 99, for: .execname("myapp"))
    /// ```
    public static func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
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
    /// let script = DBlocks.processExec()
    /// ```
    public static func processExec() -> DBlocks {
        DBlocks {
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
    /// let script = DBlocks.ioBytes(for: .execname("nginx"))
    /// ```
    public static func ioBytes(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
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
    /// let script = DBlocks.syscallLatency("read", for: .execname("nginx"))
    /// ```
    public static func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
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

    /// Logs every TCP connection that is established or torn down.
    ///
    /// Uses the `tcp` provider's `state-change` probes. Each line shows
    /// the previous and current TCP state along with the local and
    /// remote addresses; pair with `Target(.execname("…"))` to scope it
    /// to a single program.
    ///
    /// ```swift
    /// let script = DBlocks.tcpConnections(for: .execname("nginx"))
    /// ```
    public static func tcpConnections(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
            Probe("tcp:::state-change") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s[%d]: %s -> %s",
                       "execname", "pid",
                       "tcp_state_string[args[5]->tcps_state]",
                       "tcp_state_string[args[3]->tcps_state]")
            }
        }
    }

    /// Counts page faults by process.
    ///
    /// Major faults (`vminfo:::maj_fault`) require a disk read; minor
    /// faults (`vminfo:::as_fault`) just need to map a page that's
    /// already in memory. Both are returned as separate aggregations
    /// keyed by process name.
    ///
    /// ```swift
    /// let script = DBlocks.pageFaults(for: .execname("postgres"))
    /// ```
    public static func pageFaults(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
            Probe("vminfo:::maj_fault") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Count(by: "execname", into: "major_faults")
            }
            Probe("vminfo:::as_fault") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Count(by: "execname", into: "minor_faults")
            }
        }
    }

    /// Builds a histogram of block-I/O sizes.
    ///
    /// Uses the `io` provider's `start` probe so the size is the
    /// requested transfer length, not the kernel's after-the-fact tally.
    /// The histogram is keyed by execname so you can compare sizes
    /// across processes; pass a `target` to scope it.
    ///
    /// ```swift
    /// let script = DBlocks.diskIOSizes(for: .execname("postgres"))
    /// ```
    public static func diskIOSizes(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
            Probe("io:::start") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Quantize("args[0]->b_bcount", by: "execname", into: "io_size")
            }
        }
    }

    /// Logs every signal delivered to a process.
    ///
    /// Uses the `proc:::signal-send` probe. Each entry shows the
    /// sending and receiving processes plus the signal number, which is
    /// the simplest way to chase 'what just killed my daemon' bugs.
    ///
    /// ```swift
    /// let script = DBlocks.signalDelivery(for: .execname("nginx"))
    /// ```
    public static func signalDelivery(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
            Probe("proc:::signal-send") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s[%d] -> %s[%d] sig=%d",
                       "execname", "pid",
                       "args[1]->pr_fname",
                       "args[1]->pr_pid",
                       "args[2]")
            }
        }
    }

    /// Latency histogram for kernel mutex acquisition.
    ///
    /// Pairs `lockstat:::adaptive-block` (the wait-time provider) into
    /// a quantize keyed by `execname`. Useful as a quick first look at
    /// kernel-level lock contention; for production debugging, follow
    /// up with stack traces.
    ///
    /// ```swift
    /// let script = DBlocks.mutexContention()
    /// ```
    public static func mutexContention(for target: DTraceTarget = .all) -> DBlocks {
        DBlocks {
            Probe("lockstat:::adaptive-block") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Quantize("arg1", by: "execname", into: "mutex_wait_ns")
            }
        }
    }
}
