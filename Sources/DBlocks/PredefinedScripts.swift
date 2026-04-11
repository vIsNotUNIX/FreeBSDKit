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

// MARK: - dwatch-style profiles
//
// FreeBSD ships dwatch(1), a shell-script wrapper around dtrace(1) with
// 80+ canned profiles in /usr/libexec/dwatch/. Each profile attaches a
// printf-style "execname[pid]: details" line to a particular probe.
// These DBlocks helpers reproduce the most useful of those profiles in
// typed Swift form so you don't have to pipe text from dwatch when you
// need the same result programmatically.
//
// All of these scripts use the canonical dwatch output format —
//     "<execname>[<pid>]: <details>"
// — which is why they're grouped under `Dwatch.*`.

extension DBlocks {

    /// dwatch-equivalent helpers grouped under one namespace.
    ///
    /// These mirror the most useful dwatch(1) profiles
    /// (`/usr/libexec/dwatch/*`) but return a `DBlocks` you can run,
    /// capture, lint, snapshot, or compose with other scripts. Each
    /// uses the canonical `execname[pid]: …` line format dwatch
    /// produces.
    public enum Dwatch {

        // MARK: - kill / signals

        /// Equivalent to `dwatch kill` — log every kill(2) entry with
        /// the target pid and signal number.
        public static func kill(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall::kill:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: signal %d to pid %d",
                           "execname", "pid", "(int)arg1", "(pid_t)arg0")
                }
            }
        }

        // MARK: - file open / read / write

        /// Equivalent to `dwatch open` — log every open/openat with
        /// the path argument.
        public static func open(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall::open:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: open %s",
                           "execname", "pid", "copyinstr(arg0)")
                }
                Probe("syscall::openat:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: openat %s",
                           "execname", "pid", "copyinstr(arg1)")
                }
            }
        }

        /// Equivalent to `dwatch read` / `dwatch write` — print every
        /// read or write entry with the requested byte count.
        public static func readWrite(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall::read:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: read fd=%d nbyte=%d",
                           "execname", "pid", "(int)arg0", "(size_t)arg2")
                }
                Probe("syscall::write:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: write fd=%d nbyte=%d",
                           "execname", "pid", "(int)arg0", "(size_t)arg2")
                }
            }
        }

        // MARK: - chmod family

        /// Equivalent to `dwatch chmod` / `dwatch fchmodat` /
        /// `dwatch lchmod` — log every chmod-family call with its mode
        /// argument.
        public static func chmod(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall::chmod:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: chmod %s mode=%o",
                           "execname", "pid", "copyinstr(arg0)", "(mode_t)arg1")
                }
                Probe("syscall::fchmodat:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: fchmodat %s mode=%o",
                           "execname", "pid", "copyinstr(arg1)", "(mode_t)arg2")
                }
                Probe("syscall::lchmod:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: lchmod %s mode=%o",
                           "execname", "pid", "copyinstr(arg0)", "(mode_t)arg1")
                }
            }
        }

        // MARK: - process life-cycle

        /// Equivalent to `dwatch proc-exec-success` /
        /// `proc-exec-failure` — log every process exec attempt and
        /// whether it succeeded.
        public static func procExec(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("proc:::exec-success") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: exec ok %s",
                           "execname", "pid", "curpsinfo->pr_psargs")
                }
                Probe("proc:::exec-failure") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: exec FAIL errno=%d",
                           "execname", "pid", "args[0]")
                }
            }
        }

        /// Equivalent to `dwatch proc-exit` — log every process exit
        /// with reason and status.
        public static func procExit(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("proc:::exit") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: exit reason=%d",
                           "execname", "pid", "args[0]")
                }
            }
        }

        // MARK: - networking

        /// Equivalent to `dwatch tcp-state-change` — log every TCP
        /// state transition with previous and current state.
        public static func tcp(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("tcp:::state-change") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: tcp %s -> %s",
                           "execname", "pid",
                           "tcp_state_string[args[5]->tcps_state]",
                           "tcp_state_string[args[3]->tcps_state]")
                }
            }
        }

        /// Equivalent to `dwatch udp-receive` / `udp-send` — log every
        /// UDP datagram in either direction.
        public static func udp(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("udp:::receive") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: udp recv len=%d",
                           "execname", "pid", "args[2]->ip_plength")
                }
                Probe("udp:::send") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: udp send len=%d",
                           "execname", "pid", "args[2]->ip_plength")
                }
            }
        }

        // MARK: - sleep

        /// Equivalent to `dwatch nanosleep` — log every nanosleep call
        /// with the requested duration.
        public static func nanosleep(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall::nanosleep:entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: nanosleep",
                           "execname", "pid")
                }
            }
        }

        // MARK: - errno

        /// Equivalent to `dwatch errno` — log every syscall return
        /// that delivered a non-zero errno.
        public static func errnoTracer(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall:::return") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    When("errno != 0")
                    Printf("%s[%d]: %s -> errno %d",
                           "execname", "pid", "probefunc", "errno")
                }
            }
        }

        // MARK: - sysstat-style top of syscalls

        /// Equivalent to `dwatch systop` — count every syscall by
        /// `execname` + `probefunc` and print the top callers when the
        /// session exits. The output is consumable via
        /// `DTraceSession.snapshot()` for typed access.
        public static func systop(for target: DTraceTarget = .all) -> DBlocks {
            DBlocks {
                Probe("syscall:::entry") {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Count(by: ["execname", "probefunc"], into: "syscalls")
                }
                END {
                    Printa("syscalls")
                }
            }
        }

        // MARK: - kinst (FreeBSD 14+; amd64, aarch64, riscv)

        /// Trace an arbitrary instruction inside a kernel function via
        /// the `kinst` provider.
        ///
        /// `kinst` (kernel INSTruction tracing, FreeBSD 14.0+) lets
        /// you hook any instruction in a kernel function by its byte
        /// offset from the function start. Find the offset by
        /// disassembling the function with `kgdb`'s `disas /r`. Pass
        /// `offset: nil` to trace **every** instruction in the
        /// function (the firehose form — be careful on hot paths).
        ///
        /// ```swift
        /// // Trace the third instruction in vm_fault
        /// let s = DBlocks.Dwatch.kinst(function: "vm_fault", offset: 4)
        ///
        /// // Trace every instruction in amd64_syscall
        /// let s = DBlocks.Dwatch.kinst(function: "amd64_syscall")
        /// ```
        ///
        /// - Important: KINST first appeared in **FreeBSD 14.0**.
        ///   As of FreeBSD 15 it is implemented for **amd64,
        ///   aarch64, and riscv** — i386, arm, and powerpc are not
        ///   supported. The `dtrace_kinst(4)` man page on some 14.x
        ///   and 15.x systems still says "amd64 only"; the code
        ///   itself supports the three architectures above.
        ///
        /// - Parameters:
        ///   - function: Kernel function name.
        ///   - offset: Byte offset from the function start, or `nil`
        ///     to trace every instruction in the function.
        ///   - target: Optional `DTraceTarget` filter (rarely useful
        ///     for kernel-side probes, but supported for symmetry
        ///     with the rest of the `Dwatch.*` set).
        public static func kinst(
            function: String,
            offset: Int? = nil,
            for target: DTraceTarget = .all
        ) -> DBlocks {
            let offsetLabel = offset.map(String.init) ?? "all"
            return DBlocks {
                Probe(.kinst(function: function, offset: offset)) {
                    if !target.predicate.isEmpty {
                        Target(target)
                    }
                    Printf("%s[%d]: \(function)+\(offsetLabel)",
                           "execname", "pid")
                }
            }
        }
    }
}
