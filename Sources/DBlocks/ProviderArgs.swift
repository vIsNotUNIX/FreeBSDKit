/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Typed args[N] for stable DTrace providers
//
// DTrace's stable providers expose their arguments via translator
// types declared in the system D library files (`net.d`, `procfs.d`,
// `io.d`, etc.). The translator types make `args[0]->ip_plength` mean
// the same thing across kernel versions, and the field names are
// part of the stable provider interface.
//
// Each enum below is uninhabited — it exists only as a namespace —
// and exposes one static `DExpr` property per documented field. The
// rendered form is the literal D source you'd write by hand. Pair
// these with `Probe(.tcp(.send))`, `Probe(.proc(.signalSend))`, etc.
//
// Quick example:
//
// ```swift
// Probe(.tcp(.send)) {
//     Printf("%s -> %s len=%d",
//            args: [.inetNtoa(TCPArgs.ipSrcAddr),
//                   .inetNtoa(TCPArgs.ipDstAddr),
//                   TCPArgs.ipPacketLength])
// }
// ```
//
// Provider-arg field names track FreeBSD's stable provider headers
// (`/usr/lib/dtrace/{io,net,procfs,...}.d`). Where a single provider
// passes pointers to several typed structs in different `args[N]`
// slots, the namespace groups them by struct and includes the slot
// number in the property's docstring.

// MARK: - proc

/// Typed accessors for `proc` provider arguments.
///
/// The `proc` provider's signal/exec/exit probes pass at most three
/// args:
/// - `args[0]` = `lwpsinfo_t *` (target LWP) on signal-send/discard,
///               `string` (path) on `exec*`, `int` (errno) on
///               `exec-failure`
/// - `args[1]` = `psinfo_t *` (target process) on signal probes
/// - `args[2]` = `int` signal number on signal-send/discard
public enum ProcArgs {

    /// `args[0]` as `lwpsinfo_t *` — only meaningful on
    /// `signal-send`, `signal-discard`, `signal-clear`, and the
    /// `lwp-*` events.
    public static var targetLwp: DExpr { DExpr("args[0]") }

    /// `args[1]` as `psinfo_t *` — the *target* process for the
    /// signal probes; the receiving process for `signal-send`.
    public static var targetProc: DExpr { DExpr("args[1]") }

    /// `args[1]->pr_fname` — short binary name of the target process.
    public static var targetExecname: DExpr { DExpr("args[1]->pr_fname") }

    /// `args[1]->pr_psargs` — full command line of the target process.
    public static var targetCmdline: DExpr { DExpr("args[1]->pr_psargs") }

    /// `args[1]->pr_pid` — PID of the target process.
    public static var targetPid: DExpr { DExpr("args[1]->pr_pid") }

    /// `args[1]->pr_uid` — real user ID of the target.
    public static var targetUid: DExpr { DExpr("args[1]->pr_uid") }

    /// `args[1]->pr_gid` — real group ID of the target.
    public static var targetGid: DExpr { DExpr("args[1]->pr_gid") }

    /// `args[2]` as the signal number on `signal-send` /
    /// `signal-discard` / `signal-clear`.
    public static var signalNumber: DExpr { DExpr("args[2]") }

    /// `args[0]` as `string` on `exec` / `exec-success` — the path
    /// of the new program. On `exec-failure`, `args[0]` is the
    /// errno value instead; use ``execFailureErrno`` for that.
    public static var execPath: DExpr { DExpr("args[0]") }

    /// `args[0]` as `int` errno on `exec-failure`.
    public static var execFailureErrno: DExpr { DExpr("args[0]") }
}

// MARK: - io

/// Typed accessors for `io` provider arguments.
///
/// - `args[0]` = `bufinfo_t *` — the in-flight buffer
/// - `args[1]` = `devinfo_t *` — the device the I/O is going to
/// - `args[2]` = `fileinfo_t *` — the file (when known)
public enum IOArgs {

    // bufinfo_t — args[0]

    /// `args[0]` as `bufinfo_t *`.
    public static var buf: DExpr { DExpr("args[0]") }

    /// `args[0]->b_bcount` — total transfer size in bytes.
    public static var bufCount: DExpr { DExpr("args[0]->b_bcount") }

    /// `args[0]->b_resid` — bytes not yet completed.
    public static var bufResid: DExpr { DExpr("args[0]->b_resid") }

    /// `args[0]->b_flags` — buffer status flags (`B_*`).
    public static var bufFlags: DExpr { DExpr("args[0]->b_flags") }

    /// `args[0]->b_blkno` — starting block number.
    public static var bufBlkno: DExpr { DExpr("args[0]->b_blkno") }

    /// `args[0]->b_addr` — kernel virtual address of the data buffer.
    public static var bufAddr: DExpr { DExpr("args[0]->b_addr") }

    // devinfo_t — args[1]

    /// `args[1]` as `devinfo_t *`.
    public static var dev: DExpr { DExpr("args[1]") }

    /// `args[1]->dev_major` — major device number.
    public static var devMajor: DExpr { DExpr("args[1]->dev_major") }

    /// `args[1]->dev_minor` — minor device number.
    public static var devMinor: DExpr { DExpr("args[1]->dev_minor") }

    /// `args[1]->dev_instance` — instance number for multi-unit
    /// drivers.
    public static var devInstance: DExpr { DExpr("args[1]->dev_instance") }

    /// `args[1]->dev_name` — driver name (e.g. `"da"`, `"ada"`,
    /// `"nvd"`).
    public static var devName: DExpr { DExpr("args[1]->dev_name") }

    /// `args[1]->dev_statname` — `iostat`-style display name.
    public static var devStatname: DExpr { DExpr("args[1]->dev_statname") }

    /// `args[1]->dev_pathname` — full /dev pathname of the device.
    public static var devPathname: DExpr { DExpr("args[1]->dev_pathname") }

    // fileinfo_t — args[2]

    /// `args[2]` as `fileinfo_t *`.
    public static var file: DExpr { DExpr("args[2]") }

    /// `args[2]->fi_name` — basename of the file being accessed.
    public static var fileName: DExpr { DExpr("args[2]->fi_name") }

    /// `args[2]->fi_dirname` — directory containing the file.
    public static var fileDirname: DExpr { DExpr("args[2]->fi_dirname") }

    /// `args[2]->fi_pathname` — full pathname.
    public static var filePathname: DExpr { DExpr("args[2]->fi_pathname") }

    /// `args[2]->fi_offset` — offset within the file.
    public static var fileOffset: DExpr { DExpr("args[2]->fi_offset") }

    /// `args[2]->fi_fs` — filesystem type name.
    public static var fileFs: DExpr { DExpr("args[2]->fi_fs") }

    /// `args[2]->fi_mount` — mount point.
    public static var fileMount: DExpr { DExpr("args[2]->fi_mount") }

    /// `args[2]->fi_oflags` — `open(2)` flags used to open the file.
    public static var fileOflags: DExpr { DExpr("args[2]->fi_oflags") }
}

// MARK: - tcp / udp / udplite / ip — shared pktinfo / csinfo / ipinfo

/// Common arg slots shared by the `tcp`, `udp`, `udplite`, and `ip`
/// providers. The first three slots are identical across all four:
/// - `args[0]` = `pktinfo_t *`
/// - `args[1]` = `csinfo_t *`
/// - `args[2]` = `ipinfo_t *`
///
/// Provider-specific socket and protocol-header slots live in the
/// per-provider namespaces below (``TCPArgs``, ``UDPArgs``,
/// ``IPArgs``).
public enum NetArgs {

    // pktinfo_t — args[0]

    /// `args[0]->pkt_addr` — kernel-level packet address. Mostly
    /// useful as a key in aggregations.
    public static var packetAddr: DExpr { DExpr("args[0]->pkt_addr") }

    // csinfo_t — args[1]

    /// `args[1]->cs_cid` — connection ID (`uint64_t`).
    public static var connectionId: DExpr { DExpr("args[1]->cs_cid") }

    /// `args[1]->cs_pid` — PID owning this connection (or `-1`).
    public static var connectionPid: DExpr { DExpr("args[1]->cs_pid") }

    // ipinfo_t — args[2]

    /// `args[2]->ip_ver` — IP version (4 or 6).
    public static var ipVer: DExpr { DExpr("args[2]->ip_ver") }

    /// `args[2]->ip_plength` — total IP payload length in bytes.
    public static var ipPacketLength: DExpr { DExpr("args[2]->ip_plength") }

    /// `args[2]->ip_saddr` — source address as a printable string.
    public static var ipSrcAddr: DExpr { DExpr("args[2]->ip_saddr") }

    /// `args[2]->ip_daddr` — destination address as a printable string.
    public static var ipDstAddr: DExpr { DExpr("args[2]->ip_daddr") }
}

// MARK: - tcp

/// Typed accessors for `tcp` provider arguments. Inherits the
/// shared slots from ``NetArgs`` for `args[0]…args[2]` and adds the
/// TCP-specific socket and packet-header slots:
/// - `args[3]` = `tcpsinfo_t *` — TCP socket state
/// - `args[4]` = `tcpinfo_t *` — TCP packet header
public enum TCPArgs {

    // Re-export the shared NetArgs accessors so callers don't have
    // to remember which slot lives in NetArgs vs. TCPArgs.

    public static var packetAddr:     DExpr { NetArgs.packetAddr }
    public static var connectionId:   DExpr { NetArgs.connectionId }
    public static var connectionPid:  DExpr { NetArgs.connectionPid }
    public static var ipVer:          DExpr { NetArgs.ipVer }
    public static var ipPacketLength: DExpr { NetArgs.ipPacketLength }
    public static var ipSrcAddr:      DExpr { NetArgs.ipSrcAddr }
    public static var ipDstAddr:      DExpr { NetArgs.ipDstAddr }

    // tcpsinfo_t — args[3]

    /// `args[3]->tcps_lport` — local TCP port number.
    public static var localPort: DExpr { DExpr("args[3]->tcps_lport") }

    /// `args[3]->tcps_rport` — remote TCP port number.
    public static var remotePort: DExpr { DExpr("args[3]->tcps_rport") }

    /// `args[3]->tcps_laddr` — local address as a printable string.
    public static var localAddr: DExpr { DExpr("args[3]->tcps_laddr") }

    /// `args[3]->tcps_raddr` — remote address as a printable string.
    public static var remoteAddr: DExpr { DExpr("args[3]->tcps_raddr") }

    /// `args[3]->tcps_state` — TCP state (one of the `TCPS_*`
    /// constants in `<netinet/tcp_fsm.h>`).
    public static var state: DExpr { DExpr("args[3]->tcps_state") }

    /// `args[3]->tcps_iss` — initial send sequence number.
    public static var initialSendSeq: DExpr { DExpr("args[3]->tcps_iss") }

    /// `args[3]->tcps_active` — whether this end actively opened the
    /// connection.
    public static var active: DExpr { DExpr("args[3]->tcps_active") }

    // tcpinfo_t — args[4]

    /// `args[4]->tcp_sport` — source port from the TCP header.
    public static var sourcePort: DExpr { DExpr("args[4]->tcp_sport") }

    /// `args[4]->tcp_dport` — destination port from the TCP header.
    public static var destPort: DExpr { DExpr("args[4]->tcp_dport") }

    /// `args[4]->tcp_seq` — TCP sequence number.
    public static var sequence: DExpr { DExpr("args[4]->tcp_seq") }

    /// `args[4]->tcp_ack` — TCP acknowledgement number.
    public static var ackNumber: DExpr { DExpr("args[4]->tcp_ack") }

    /// `args[4]->tcp_offset` — data offset (header length / 4).
    public static var offset: DExpr { DExpr("args[4]->tcp_offset") }

    /// `args[4]->tcp_flags` — flag bits (`SYN`, `ACK`, `FIN`, `RST`,
    /// `PSH`, `URG`, …).
    public static var flags: DExpr { DExpr("args[4]->tcp_flags") }

    /// `args[4]->tcp_window` — TCP window size.
    public static var window: DExpr { DExpr("args[4]->tcp_window") }

    /// `args[4]->tcp_checksum` — TCP checksum.
    public static var checksum: DExpr { DExpr("args[4]->tcp_checksum") }
}

// MARK: - udp / udplite

/// Typed accessors for `udp` provider arguments. Inherits the
/// shared `NetArgs` slots for `args[0…2]` and adds:
/// - `args[3]` = `udpsinfo_t *` — UDP socket state
/// - `args[4]` = `udpinfo_t *` — UDP packet header
public enum UDPArgs {

    public static var packetAddr:     DExpr { NetArgs.packetAddr }
    public static var connectionId:   DExpr { NetArgs.connectionId }
    public static var connectionPid:  DExpr { NetArgs.connectionPid }
    public static var ipVer:          DExpr { NetArgs.ipVer }
    public static var ipPacketLength: DExpr { NetArgs.ipPacketLength }
    public static var ipSrcAddr:      DExpr { NetArgs.ipSrcAddr }
    public static var ipDstAddr:      DExpr { NetArgs.ipDstAddr }

    // udpsinfo_t — args[3]

    /// `args[3]->udps_lport` — local UDP port number.
    public static var localPort: DExpr { DExpr("args[3]->udps_lport") }

    /// `args[3]->udps_rport` — remote UDP port number.
    public static var remotePort: DExpr { DExpr("args[3]->udps_rport") }

    /// `args[3]->udps_laddr` — local address as a printable string.
    public static var localAddr: DExpr { DExpr("args[3]->udps_laddr") }

    /// `args[3]->udps_raddr` — remote address as a printable string.
    public static var remoteAddr: DExpr { DExpr("args[3]->udps_raddr") }

    // udpinfo_t — args[4]

    /// `args[4]->udp_sport` — source port from the UDP header.
    public static var sourcePort: DExpr { DExpr("args[4]->udp_sport") }

    /// `args[4]->udp_dport` — destination port from the UDP header.
    public static var destPort: DExpr { DExpr("args[4]->udp_dport") }

    /// `args[4]->udp_length` — UDP length field (header + data).
    public static var length: DExpr { DExpr("args[4]->udp_length") }

    /// `args[4]->udp_checksum` — UDP checksum.
    public static var checksum: DExpr { DExpr("args[4]->udp_checksum") }
}

/// Typed accessors for `udplite` provider arguments — identical
/// shape to ``UDPArgs``, with checksum coverage instead of length
/// in the protocol-specific slot.
public enum UDPLiteArgs {

    public static var packetAddr:     DExpr { NetArgs.packetAddr }
    public static var connectionId:   DExpr { NetArgs.connectionId }
    public static var connectionPid:  DExpr { NetArgs.connectionPid }
    public static var ipVer:          DExpr { NetArgs.ipVer }
    public static var ipPacketLength: DExpr { NetArgs.ipPacketLength }
    public static var ipSrcAddr:      DExpr { NetArgs.ipSrcAddr }
    public static var ipDstAddr:      DExpr { NetArgs.ipDstAddr }

    /// `args[3]->udplites_lport` — local UDP-Lite port.
    public static var localPort: DExpr { DExpr("args[3]->udplites_lport") }

    /// `args[3]->udplites_rport` — remote UDP-Lite port.
    public static var remotePort: DExpr { DExpr("args[3]->udplites_rport") }

    /// `args[3]->udplites_laddr` — local address as a printable string.
    public static var localAddr: DExpr { DExpr("args[3]->udplites_laddr") }

    /// `args[3]->udplites_raddr` — remote address as a printable string.
    public static var remoteAddr: DExpr { DExpr("args[3]->udplites_raddr") }

    /// `args[4]->udplite_coverage` — checksum coverage length.
    public static var coverage: DExpr { DExpr("args[4]->udplite_coverage") }

    /// `args[4]->udplite_checksum` — UDP-Lite checksum.
    public static var checksum: DExpr { DExpr("args[4]->udplite_checksum") }
}

// MARK: - ip

/// Typed accessors for `ip` provider arguments. Inherits the
/// shared `NetArgs` slots for `args[0…2]` and adds:
/// - `args[3]` = `ifinfo_t *` — interface info
/// - `args[4]` = `ipv4info_t *` — IPv4 header (when ip_ver == 4)
/// - `args[5]` = `ipv6info_t *` — IPv6 header (when ip_ver == 6)
public enum IPArgs {

    public static var packetAddr:     DExpr { NetArgs.packetAddr }
    public static var connectionId:   DExpr { NetArgs.connectionId }
    public static var connectionPid:  DExpr { NetArgs.connectionPid }
    public static var ipVer:          DExpr { NetArgs.ipVer }
    public static var ipPacketLength: DExpr { NetArgs.ipPacketLength }
    public static var ipSrcAddr:      DExpr { NetArgs.ipSrcAddr }
    public static var ipDstAddr:      DExpr { NetArgs.ipDstAddr }

    // ifinfo_t — args[3]

    /// `args[3]->if_name` — interface name (e.g. `"em0"`, `"lo0"`).
    public static var ifName: DExpr { DExpr("args[3]->if_name") }

    /// `args[3]->if_local` — non-zero if this is a loopback packet.
    public static var ifLocal: DExpr { DExpr("args[3]->if_local") }

    /// `args[3]->if_addr` — interface address as a printable string.
    public static var ifAddr: DExpr { DExpr("args[3]->if_addr") }

    /// `args[3]->if_ipver` — IP version of the interface.
    public static var ifIpVer: DExpr { DExpr("args[3]->if_ipver") }

    // ipv4info_t — args[4]

    /// `args[4]->ipv4_ver` — IPv4 version (always 4).
    public static var ipv4Ver: DExpr { DExpr("args[4]->ipv4_ver") }

    /// `args[4]->ipv4_ihl` — IPv4 header length / 4.
    public static var ipv4Ihl: DExpr { DExpr("args[4]->ipv4_ihl") }

    /// `args[4]->ipv4_tos` — IPv4 type-of-service byte.
    public static var ipv4Tos: DExpr { DExpr("args[4]->ipv4_tos") }

    /// `args[4]->ipv4_length` — total IPv4 datagram length.
    public static var ipv4Length: DExpr { DExpr("args[4]->ipv4_length") }

    /// `args[4]->ipv4_ident` — IPv4 identification field.
    public static var ipv4Ident: DExpr { DExpr("args[4]->ipv4_ident") }

    /// `args[4]->ipv4_protocol` — protocol number (TCP=6, UDP=17, …).
    public static var ipv4Protocol: DExpr { DExpr("args[4]->ipv4_protocol") }

    /// `args[4]->ipv4_checksum` — IPv4 header checksum.
    public static var ipv4Checksum: DExpr { DExpr("args[4]->ipv4_checksum") }

    /// `args[4]->ipv4_src` — IPv4 source address as a printable string.
    public static var ipv4Src: DExpr { DExpr("args[4]->ipv4_src") }

    /// `args[4]->ipv4_dst` — IPv4 destination address.
    public static var ipv4Dst: DExpr { DExpr("args[4]->ipv4_dst") }

    // ipv6info_t — args[5]

    /// `args[5]->ipv6_ver` — IPv6 version (always 6).
    public static var ipv6Ver: DExpr { DExpr("args[5]->ipv6_ver") }

    /// `args[5]->ipv6_plen` — IPv6 payload length.
    public static var ipv6Plen: DExpr { DExpr("args[5]->ipv6_plen") }

    /// `args[5]->ipv6_nexthdr` — IPv6 next-header byte.
    public static var ipv6NextHdr: DExpr { DExpr("args[5]->ipv6_nexthdr") }

    /// `args[5]->ipv6_hlim` — IPv6 hop limit.
    public static var ipv6HopLimit: DExpr { DExpr("args[5]->ipv6_hlim") }

    /// `args[5]->ipv6_src` — IPv6 source address as a printable string.
    public static var ipv6Src: DExpr { DExpr("args[5]->ipv6_src") }

    /// `args[5]->ipv6_dst` — IPv6 destination address.
    public static var ipv6Dst: DExpr { DExpr("args[5]->ipv6_dst") }
}

// MARK: - sched

/// Typed accessors for `sched` provider arguments.
///
/// - `args[0]` = `lwpsinfo_t *` — target LWP (the thread being
///               scheduled / unscheduled)
/// - `args[1]` = `psinfo_t *` — target process
/// - `args[2]` = `cpuinfo_t *` — target CPU
public enum SchedArgs {

    /// `args[0]` as `lwpsinfo_t *`.
    public static var targetLwp: DExpr { DExpr("args[0]") }

    /// `args[0]->pr_lwpid` — LWP id.
    public static var targetLwpId: DExpr { DExpr("args[0]->pr_lwpid") }

    /// `args[0]->pr_state` — LWP state code.
    public static var targetLwpState: DExpr { DExpr("args[0]->pr_state") }

    /// `args[0]->pr_pri` — current scheduling priority.
    public static var targetLwpPri: DExpr { DExpr("args[0]->pr_pri") }

    /// `args[1]` as `psinfo_t *`.
    public static var targetProc: DExpr { DExpr("args[1]") }

    /// `args[1]->pr_fname` — short binary name of the target proc.
    public static var targetExecname: DExpr { DExpr("args[1]->pr_fname") }

    /// `args[1]->pr_pid` — PID of the target proc.
    public static var targetPid: DExpr { DExpr("args[1]->pr_pid") }

    /// `args[2]` as `cpuinfo_t *`.
    public static var targetCpu: DExpr { DExpr("args[2]") }

    /// `args[2]->cpu_id` — numeric CPU id.
    public static var targetCpuId: DExpr { DExpr("args[2]->cpu_id") }
}

// MARK: - lockstat

/// Typed accessors for `lockstat` provider arguments.
///
/// `lockstat` does not use translator types — its args are raw
/// pointers and integers — but the slot meanings are part of its
/// stable interface, so we expose them as named accessors.
///
/// - `args[0]` = `void *` lock pointer
/// - `args[1]` = wait time (ns) for `*-block` probes,
///               spin count for `*-spin` probes,
///               unused for `*-acquire` / `*-release`
/// - `args[2]` = (rw probes only) writer flag — non-zero if the
///               lock was acquired in writer mode
public enum LockstatArgs {

    /// `args[0]` — pointer to the lock that is being acquired,
    /// blocked on, spun on, or released.
    public static var lockPointer: DExpr { DExpr("args[0]") }

    /// `args[1]` — for `*-block` probes, the time (in nanoseconds)
    /// the caller spent waiting. For `*-spin` probes, the spin count.
    public static var waitTimeOrSpinCount: DExpr { DExpr("args[1]") }

    /// `args[2]` — only meaningful on `rw-acquire`: non-zero if
    /// the lock was acquired in writer mode.
    public static var rwWriterFlag: DExpr { DExpr("args[2]") }
}
