/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Extended Dwatch profile catalog
//
// This file extends `DBlocks.Dwatch` with a wide catalog of per-event
// and per-syscall profiles. Together with the curated profiles in
// PredefinedScripts.swift it brings the total Dwatch surface to
// roughly 300 named profiles, covering every event the proc/sched/io/
// tcp/udp/udplite/ip/vminfo/lockstat/vfs providers expose plus the
// most-traced syscalls.
//
// Every profile in this file follows the same shape: enable a single
// well-known probe (or a small fixed set) and Printf the firing
// probename together with execname/pid. Custom predicates and field
// extraction are out of scope — users who want richer logging should
// build a custom script with `Probe(...)`.
//
// The wrappers are deliberately uniform so that the parameterized
// canary test (see DBlocksTests.swift) can verify validate + lint
// clean + JSON round-trip for every entry from a single static list.

extension DBlocks.Dwatch {

    // MARK: - Internal helpers

    /// Single-probe profile that prints execname/pid plus the firing
    /// probename. Used by every per-event wrapper below.
    fileprivate static func probeProfile(
        _ probe: String,
        for target: DTraceTarget
    ) -> DBlocks {
        DBlocks {
            Probe(probe) {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s[%d]: %s",
                       "execname", "pid", "probename")
            }
        }
    }

    /// Multi-probe profile sharing a single body — used where a
    /// dwatch-style alias enables a small fixed set of related probes.
    fileprivate static func multiProbeProfile(
        _ probes: [String],
        for target: DTraceTarget
    ) -> DBlocks {
        DBlocks {
            Probe(probes: probes) {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s[%d]: %s",
                       "execname", "pid", "probename")
            }
        }
    }

    /// Syscall entry/return profile that prints execname/pid and
    /// `probefunc` (the syscall name). The probefunc-based label means
    /// a single helper covers every named syscall — the public
    /// per-syscall wrappers below are just one-line factories that
    /// pin the syscall name.
    fileprivate static func syscallProfile(
        _ name: String,
        site: String,
        for target: DTraceTarget
    ) -> DBlocks {
        DBlocks {
            Probe("syscall::\(name):\(site)") {
                if !target.predicate.isEmpty {
                    Target(target)
                }
                Printf("%s[%d]: %s %s",
                       "execname", "pid", "probefunc", site)
            }
        }
    }

    // MARK: - proc provider (one profile per event)

    public static func procCreate(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::create", for: target)
    }
    public static func procExecEvent(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::exec", for: target)
    }
    public static func procExecSuccess(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::exec-success", for: target)
    }
    public static func procExecFailure(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::exec-failure", for: target)
    }
    public static func procExitEvent(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::exit", for: target)
    }
    public static func procFault(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::fault", for: target)
    }
    public static func procLwpCreate(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::lwp-create", for: target)
    }
    public static func procLwpExit(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::lwp-exit", for: target)
    }
    public static func procLwpStart(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::lwp-start", for: target)
    }
    public static func procSignalSendEvent(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::signal-send", for: target)
    }
    public static func procSignalDiscard(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::signal-discard", for: target)
    }
    public static func procSignalHandle(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::signal-handle", for: target)
    }
    public static func procSignalClear(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::signal-clear", for: target)
    }
    public static func procStartEvent(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("proc:::start", for: target)
    }

    // MARK: - sched provider

    public static func schedSleep(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::sleep", for: target)
    }
    public static func schedWakeup(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::wakeup", for: target)
    }
    public static func schedOnCpu(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::on-cpu", for: target)
    }
    public static func schedOffCpu(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::off-cpu", for: target)
    }
    public static func schedRemainCpu(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::remain-cpu", for: target)
    }
    public static func schedChangePri(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::change-pri", for: target)
    }
    public static func schedLendPri(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::lend-pri", for: target)
    }
    public static func schedDequeue(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::dequeue", for: target)
    }
    public static func schedEnqueue(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::enqueue", for: target)
    }
    public static func schedLoadChange(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::load-change", for: target)
    }
    public static func schedSurrender(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::surrender", for: target)
    }
    public static func schedTick(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("sched:::tick", for: target)
    }

    // MARK: - io provider

    public static func ioStart(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("io:::start", for: target)
    }
    public static func ioDone(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("io:::done", for: target)
    }
    public static func ioWaitStart(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("io:::wait-start", for: target)
    }
    public static func ioWaitDone(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("io:::wait-done", for: target)
    }

    // MARK: - tcp provider

    public static func tcpAcceptEstablished(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::accept-established", for: target)
    }
    public static func tcpAcceptRefused(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::accept-refused", for: target)
    }
    public static func tcpConnectEstablished(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::connect-established", for: target)
    }
    public static func tcpConnectRefused(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::connect-refused", for: target)
    }
    public static func tcpConnectRequest(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::connect-request", for: target)
    }
    public static func tcpReceive(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::receive", for: target)
    }
    public static func tcpSend(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::send", for: target)
    }
    public static func tcpStateChange(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("tcp:::state-change", for: target)
    }

    // MARK: - udp / udplite / ip providers

    public static func udpReceive(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("udp:::receive", for: target)
    }
    public static func udpSend(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("udp:::send", for: target)
    }
    public static func udpliteReceive(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("udplite:::receive", for: target)
    }
    public static func udpliteSend(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("udplite:::send", for: target)
    }
    public static func ipReceive(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("ip:::receive", for: target)
    }
    public static func ipSend(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("ip:::send", for: target)
    }

    // MARK: - vminfo provider

    public static func vmAnonpgin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::anonpgin", for: target)
    }
    public static func vmAnonpgout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::anonpgout", for: target)
    }
    public static func vmAsFault(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::as_fault", for: target)
    }
    public static func vmCowFault(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::cow_fault", for: target)
    }
    public static func vmDfree(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::dfree", for: target)
    }
    public static func vmExecfree(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::execfree", for: target)
    }
    public static func vmExecpgin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::execpgin", for: target)
    }
    public static func vmExecpgout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::execpgout", for: target)
    }
    public static func vmFsfree(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::fsfree", for: target)
    }
    public static func vmFspgin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::fspgin", for: target)
    }
    public static func vmFspgout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::fspgout", for: target)
    }
    public static func vmKernelAsflt(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::kernel_asflt", for: target)
    }
    public static func vmMajFault(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::maj_fault", for: target)
    }
    public static func vmPgin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::pgin", for: target)
    }
    public static func vmPgout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::pgout", for: target)
    }
    public static func vmPgrec(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::pgrec", for: target)
    }
    public static func vmPgrrun(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::pgrrun", for: target)
    }
    public static func vmPrfree(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::prfree", for: target)
    }
    public static func vmPrpgin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::prpgin", for: target)
    }
    public static func vmPrpgout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::prpgout", for: target)
    }
    public static func vmScan(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::scan", for: target)
    }
    public static func vmSwapin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::swapin", for: target)
    }
    public static func vmSwapout(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::swapout", for: target)
    }
    public static func vmZfod(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("vminfo:::zfod", for: target)
    }

    // MARK: - lockstat provider

    public static func lockstatAdaptiveAcquire(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::adaptive-acquire", for: target)
    }
    public static func lockstatAdaptiveBlock(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::adaptive-block", for: target)
    }
    public static func lockstatAdaptiveSpin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::adaptive-spin", for: target)
    }
    public static func lockstatAdaptiveRelease(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::adaptive-release", for: target)
    }
    public static func lockstatRwAcquire(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::rw-acquire", for: target)
    }
    public static func lockstatRwBlock(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::rw-block", for: target)
    }
    public static func lockstatRwRelease(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::rw-release", for: target)
    }
    public static func lockstatRwUpgrade(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::rw-upgrade", for: target)
    }
    public static func lockstatRwDowngrade(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::rw-downgrade", for: target)
    }
    public static func lockstatSpinAcquire(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::spin-acquire", for: target)
    }
    public static func lockstatSpinSpin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::spin-spin", for: target)
    }
    public static func lockstatSpinRelease(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::spin-release", for: target)
    }
    public static func lockstatThreadSpin(for target: DTraceTarget = .all) -> DBlocks {
        probeProfile("lockstat:::thread-spin", for: target)
    }

    // MARK: - vfs vnode-operation probes
    //
    // FreeBSD's vfs SDT provider exposes one probe per VOP, addressed
    // as `vfs:vop:<vop_name>:entry`. Each wrapper here just enables
    // the entry probe with the standard execname/pid printf.

    fileprivate static func vopEntry(_ name: String, for target: DTraceTarget) -> DBlocks {
        probeProfile("vfs:vop:\(name):entry", for: target)
    }

    public static func vopLookup(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_lookup", for: target)
    }
    public static func vopAccess(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_access", for: target)
    }
    public static func vopOpen(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_open", for: target)
    }
    public static func vopClose(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_close", for: target)
    }
    public static func vopGetattr(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_getattr", for: target)
    }
    public static func vopSetattr(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_setattr", for: target)
    }
    public static func vopRead(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_read", for: target)
    }
    public static func vopWrite(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_write", for: target)
    }
    public static func vopIoctl(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_ioctl", for: target)
    }
    public static func vopPoll(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_poll", for: target)
    }
    public static func vopKqfilter(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_kqfilter", for: target)
    }
    public static func vopFsync(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_fsync", for: target)
    }
    public static func vopRemove(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_remove", for: target)
    }
    public static func vopLink(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_link", for: target)
    }
    public static func vopMkdir(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_mkdir", for: target)
    }
    public static func vopRmdir(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_rmdir", for: target)
    }
    public static func vopReadlink(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_readlink", for: target)
    }
    public static func vopInactive(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_inactive", for: target)
    }
    public static func vopReclaim(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_reclaim", for: target)
    }
    public static func vopLock(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_lock1", for: target)
    }
    public static func vopUnlock(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_unlock", for: target)
    }
    public static func vopIslocked(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_islocked", for: target)
    }
    public static func vopBmap(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_bmap", for: target)
    }
    public static func vopStrategy(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_strategy", for: target)
    }
    public static func vopAdvlock(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_advlock", for: target)
    }
    public static func vopGetextattr(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_getextattr", for: target)
    }
    public static func vopSetextattr(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_setextattr", for: target)
    }
    public static func vopListextattr(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_listextattr", for: target)
    }
    public static func vopGetacl(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_getacl", for: target)
    }
    public static func vopSetacl(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_setacl", for: target)
    }
    public static func vopAclcheck(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_aclcheck", for: target)
    }
    public static func vopVptocnp(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_vptocnp", for: target)
    }
    public static func vopAllocate(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_allocate", for: target)
    }
    public static func vopDeallocate(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_deallocate", for: target)
    }
    public static func vopAdvise(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_advise", for: target)
    }
    public static func vopFdatasync(for target: DTraceTarget = .all) -> DBlocks {
        vopEntry("vop_fdatasync", for: target)
    }

    // MARK: - Curated syscall entry profiles
    //
    // The most-traced syscalls. Each wrapper is a one-liner that
    // delegates into ``syscallProfile(_:site:for:)`` so the action
    // body lives in exactly one place. Use ``syscall(_:site:for:)``
    // for any syscall not listed below.

    /// Generic per-syscall profile factory. Pin the syscall name and
    /// optionally the site (`.entry` by default).
    ///
    /// ```swift
    /// DBlocks.Dwatch.syscall("read")               // entry
    /// DBlocks.Dwatch.syscall("read", site: .return)
    /// ```
    public static func syscall(
        _ name: String,
        site: SyscallSite = .entry,
        for target: DTraceTarget = .all
    ) -> DBlocks {
        syscallProfile(name, site: site.rawValue, for: target)
    }

    /// Site selector for ``syscall(_:site:for:)``.
    public enum SyscallSite: String, Sendable {
        case entry
        case `return`
    }

    // I/O syscalls
    public static func sysReadEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("read", site: "entry", for: target) }
    public static func sysReadReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("read", site: "return", for: target) }
    public static func sysWriteEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("write", site: "entry", for: target) }
    public static func sysWriteReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("write", site: "return", for: target) }
    public static func sysPreadEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pread", site: "entry", for: target) }
    public static func sysPreadReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pread", site: "return", for: target) }
    public static func sysPwriteEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pwrite", site: "entry", for: target) }
    public static func sysPwriteReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pwrite", site: "return", for: target) }
    public static func sysReadvEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("readv", site: "entry", for: target) }
    public static func sysWritevEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("writev", site: "entry", for: target) }
    public static func sysPreadvEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("preadv", site: "entry", for: target) }
    public static func sysPwritevEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pwritev", site: "entry", for: target) }

    // File-descriptor lifecycle
    public static func sysOpenEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("open", site: "entry", for: target) }
    public static func sysOpenReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("open", site: "return", for: target) }
    public static func sysOpenatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("openat", site: "entry", for: target) }
    public static func sysOpenatReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("openat", site: "return", for: target) }
    public static func sysCloseEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("close", site: "entry", for: target) }
    public static func sysCloseReturn(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("close", site: "return", for: target) }
    public static func sysCloseRangeEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("close_range", site: "entry", for: target) }
    public static func sysDupEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("dup", site: "entry", for: target) }
    public static func sysDup2Entry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("dup2", site: "entry", for: target) }
    public static func sysFcntlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fcntl", site: "entry", for: target) }
    public static func sysIoctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("ioctl", site: "entry", for: target) }
    public static func sysPipeEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pipe", site: "entry", for: target) }
    public static func sysPipe2Entry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pipe2", site: "entry", for: target) }

    // File metadata
    public static func sysStatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("stat", site: "entry", for: target) }
    public static func sysFstatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fstat", site: "entry", for: target) }
    public static func sysLstatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("lstat", site: "entry", for: target) }
    public static func sysFstatatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fstatat", site: "entry", for: target) }
    public static func sysAccessEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("access", site: "entry", for: target) }
    public static func sysFaccessatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("faccessat", site: "entry", for: target) }
    public static func sysStatfsEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("statfs", site: "entry", for: target) }
    public static func sysFstatfsEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fstatfs", site: "entry", for: target) }

    // Filesystem mutations
    public static func sysLinkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("link", site: "entry", for: target) }
    public static func sysLinkatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("linkat", site: "entry", for: target) }
    public static func sysUnlinkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("unlink", site: "entry", for: target) }
    public static func sysUnlinkatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("unlinkat", site: "entry", for: target) }
    public static func sysFunlinkatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("funlinkat", site: "entry", for: target) }
    public static func sysRenameEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("rename", site: "entry", for: target) }
    public static func sysRenameatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("renameat", site: "entry", for: target) }
    public static func sysMkdirEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mkdir", site: "entry", for: target) }
    public static func sysMkdiratEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mkdirat", site: "entry", for: target) }
    public static func sysRmdirEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("rmdir", site: "entry", for: target) }
    public static func sysSymlinkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("symlink", site: "entry", for: target) }
    public static func sysSymlinkatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("symlinkat", site: "entry", for: target) }
    public static func sysReadlinkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("readlink", site: "entry", for: target) }
    public static func sysReadlinkatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("readlinkat", site: "entry", for: target) }
    public static func sysTruncateEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("truncate", site: "entry", for: target) }
    public static func sysFtruncateEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("ftruncate", site: "entry", for: target) }
    public static func sysLseekEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("lseek", site: "entry", for: target) }
    public static func sysFsyncEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fsync", site: "entry", for: target) }
    public static func sysFdatasyncEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fdatasync", site: "entry", for: target) }

    // Permissions / ownership
    public static func sysChmodEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("chmod", site: "entry", for: target) }
    public static func sysFchmodEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fchmod", site: "entry", for: target) }
    public static func sysLchmodEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("lchmod", site: "entry", for: target) }
    public static func sysFchmodatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fchmodat", site: "entry", for: target) }
    public static func sysChownEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("chown", site: "entry", for: target) }
    public static func sysFchownEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fchown", site: "entry", for: target) }
    public static func sysLchownEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("lchown", site: "entry", for: target) }
    public static func sysFchownatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fchownat", site: "entry", for: target) }

    // Process lifecycle
    public static func sysForkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fork", site: "entry", for: target) }
    public static func sysVforkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("vfork", site: "entry", for: target) }
    public static func sysRforkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("rfork", site: "entry", for: target) }
    public static func sysExecveEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("execve", site: "entry", for: target) }
    public static func sysFexecveEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fexecve", site: "entry", for: target) }
    public static func sysExitEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("exit", site: "entry", for: target) }
    public static func sysWait4Entry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("wait4", site: "entry", for: target) }
    public static func sysWait6Entry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("wait6", site: "entry", for: target) }

    // Signals
    public static func sysKillEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("kill", site: "entry", for: target) }
    public static func sysKillpgEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("killpg", site: "entry", for: target) }
    public static func sysSigactionEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigaction", site: "entry", for: target) }
    public static func sysSigprocmaskEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigprocmask", site: "entry", for: target) }
    public static func sysSigsuspendEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigsuspend", site: "entry", for: target) }
    public static func sysSigreturnEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigreturn", site: "entry", for: target) }
    public static func sysSigaltstackEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigaltstack", site: "entry", for: target) }
    public static func sysSigqueueEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sigqueue", site: "entry", for: target) }

    // Memory management
    public static func sysMmapEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mmap", site: "entry", for: target) }
    public static func sysMunmapEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("munmap", site: "entry", for: target) }
    public static func sysMprotectEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mprotect", site: "entry", for: target) }
    public static func sysMadviseEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("madvise", site: "entry", for: target) }
    public static func sysMsyncEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("msync", site: "entry", for: target) }
    public static func sysMlockEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mlock", site: "entry", for: target) }
    public static func sysMunlockEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("munlock", site: "entry", for: target) }
    public static func sysMincoreEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mincore", site: "entry", for: target) }
    public static func sysShmOpenEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shm_open", site: "entry", for: target) }
    public static func sysShmUnlinkEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shm_unlink", site: "entry", for: target) }
    public static func sysShmRenameEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shm_rename", site: "entry", for: target) }

    // Networking
    public static func sysSocketEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("socket", site: "entry", for: target) }
    public static func sysBindEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("bind", site: "entry", for: target) }
    public static func sysConnectEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("connect", site: "entry", for: target) }
    public static func sysListenEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("listen", site: "entry", for: target) }
    public static func sysAcceptEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("accept", site: "entry", for: target) }
    public static func sysAccept4Entry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("accept4", site: "entry", for: target) }
    public static func sysSendEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("send", site: "entry", for: target) }
    public static func sysSendtoEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sendto", site: "entry", for: target) }
    public static func sysSendmsgEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("sendmsg", site: "entry", for: target) }
    public static func sysRecvEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("recv", site: "entry", for: target) }
    public static func sysRecvfromEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("recvfrom", site: "entry", for: target) }
    public static func sysRecvmsgEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("recvmsg", site: "entry", for: target) }
    public static func sysShutdownEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shutdown", site: "entry", for: target) }
    public static func sysGetsocknameEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getsockname", site: "entry", for: target) }
    public static func sysGetpeernameEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getpeername", site: "entry", for: target) }
    public static func sysSetsockoptEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setsockopt", site: "entry", for: target) }
    public static func sysGetsockoptEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getsockopt", site: "entry", for: target) }

    // Polling / kqueue
    public static func sysSelectEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("select", site: "entry", for: target) }
    public static func sysPselectEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("pselect", site: "entry", for: target) }
    public static func sysPollEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("poll", site: "entry", for: target) }
    public static func sysPpollEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("ppoll", site: "entry", for: target) }
    public static func sysKqueueEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("kqueue", site: "entry", for: target) }
    public static func sysKeventEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("kevent", site: "entry", for: target) }

    // Time / sleep
    public static func sysNanosleepEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("nanosleep", site: "entry", for: target) }
    public static func sysClockNanosleepEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("clock_nanosleep", site: "entry", for: target) }
    public static func sysGettimeofdayEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("gettimeofday", site: "entry", for: target) }
    public static func sysClockGettimeEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("clock_gettime", site: "entry", for: target) }
    public static func sysClockSettimeEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("clock_settime", site: "entry", for: target) }
    public static func sysSetitimerEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setitimer", site: "entry", for: target) }

    // IDs / credentials / process info
    public static func sysGetpidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getpid", site: "entry", for: target) }
    public static func sysGetppidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getppid", site: "entry", for: target) }
    public static func sysGetuidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getuid", site: "entry", for: target) }
    public static func sysGeteuidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("geteuid", site: "entry", for: target) }
    public static func sysGetgidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getgid", site: "entry", for: target) }
    public static func sysGetegidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getegid", site: "entry", for: target) }
    public static func sysSetuidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setuid", site: "entry", for: target) }
    public static func sysSetgidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setgid", site: "entry", for: target) }
    public static func sysSeteuidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("seteuid", site: "entry", for: target) }
    public static func sysSetegidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setegid", site: "entry", for: target) }
    public static func sysSetresuidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setresuid", site: "entry", for: target) }
    public static func sysSetresgidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setresgid", site: "entry", for: target) }
    public static func sysSetsidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setsid", site: "entry", for: target) }
    public static func sysSetpgidEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setpgid", site: "entry", for: target) }

    // Resource control
    public static func sysGetrlimitEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getrlimit", site: "entry", for: target) }
    public static func sysSetrlimitEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setrlimit", site: "entry", for: target) }
    public static func sysGetrusageEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getrusage", site: "entry", for: target) }
    public static func sysGetpriorityEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("getpriority", site: "entry", for: target) }
    public static func sysSetpriorityEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("setpriority", site: "entry", for: target) }

    // Sysv IPC
    public static func sysSemgetEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("semget", site: "entry", for: target) }
    public static func sysSemopEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("semop", site: "entry", for: target) }
    public static func sysSemctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("semctl", site: "entry", for: target) }
    public static func sysMsggetEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("msgget", site: "entry", for: target) }
    public static func sysMsgsndEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("msgsnd", site: "entry", for: target) }
    public static func sysMsgrcvEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("msgrcv", site: "entry", for: target) }
    public static func sysMsgctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("msgctl", site: "entry", for: target) }
    public static func sysShmgetEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shmget", site: "entry", for: target) }
    public static func sysShmatEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shmat", site: "entry", for: target) }
    public static func sysShmdtEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shmdt", site: "entry", for: target) }
    public static func sysShmctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("shmctl", site: "entry", for: target) }

    // Mount / fs admin
    public static func sysMountEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("mount", site: "entry", for: target) }
    public static func sysUnmountEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("unmount", site: "entry", for: target) }
    public static func sysChdirEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("chdir", site: "entry", for: target) }
    public static func sysFchdirEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("fchdir", site: "entry", for: target) }
    public static func sysChrootEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("chroot", site: "entry", for: target) }

    // Misc high-value
    public static func sysSysctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("__sysctl", site: "entry", for: target) }
    public static func sysReboot(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("reboot", site: "entry", for: target) }
    public static func sysJailEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("jail", site: "entry", for: target) }
    public static func sysJailAttachEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("jail_attach", site: "entry", for: target) }
    public static func sysCpusetEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("cpuset", site: "entry", for: target) }
    public static func sysProcctlEntry(for target: DTraceTarget = .all) -> DBlocks { syscallProfile("procctl", site: "entry", for: target) }
}
