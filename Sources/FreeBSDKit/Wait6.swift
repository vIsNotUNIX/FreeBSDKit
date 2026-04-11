/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - Wait id type

/// Selector for which set of processes a `wait6(2)` call refers to.
///
/// Mirrors `idtype_t` in `<sys/wait.h>`. Together with the `id` argument,
/// this picks out a single process, a process group, every child, or
/// every process in a jail.
public struct WaitIdType: RawRepresentable, Sendable, Equatable {
    public let rawValue: idtype_t
    public init(rawValue: idtype_t) { self.rawValue = rawValue }

    /// `id` is a process identifier.
    public static let pid     = WaitIdType(rawValue: P_PID)
    /// `id` is a parent process identifier.
    public static let ppid    = WaitIdType(rawValue: P_PPID)
    /// `id` is a process-group identifier.
    public static let pgid    = WaitIdType(rawValue: P_PGID)
    /// `id` is a session identifier.
    public static let sid     = WaitIdType(rawValue: P_SID)
    /// `id` is a user identifier.
    public static let uid     = WaitIdType(rawValue: P_UID)
    /// `id` is a group identifier.
    public static let gid     = WaitIdType(rawValue: P_GID)
    /// Wait for any child. `id` is ignored.
    public static let all     = WaitIdType(rawValue: P_ALL)
    /// `id` is a jail identifier.
    public static let jailID  = WaitIdType(rawValue: P_JAILID)
}

// MARK: - Wait options

/// Option flags for `wait6(2)`.
public struct WaitOptions: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Don't block; return immediately if no matching child has changed
    /// state.
    public static let noHang     = WaitOptions(rawValue: WNOHANG)

    /// Report on stopped (untraced) children too.
    public static let untraced   = WaitOptions(rawValue: WUNTRACED)

    /// Report on continued children.
    public static let continued  = WaitOptions(rawValue: WCONTINUED)

    /// Leave the zombie around so a later wait can find it.
    public static let noWait     = WaitOptions(rawValue: WNOWAIT)

    /// Report on exited children. Required by `wait6` (it does not
    /// implicitly imply WEXITED the way `waitpid` does).
    public static let exited     = WaitOptions(rawValue: WEXITED)

    /// Report on traced/breakpointed children.
    public static let trapped    = WaitOptions(rawValue: WTRAPPED)
}

// MARK: - Wait6 result

/// Result of a `wait6(2)` call.
///
/// Not `Sendable` because `rusage` and `siginfo_t` are imported C
/// structs without a Sendable conformance. Copy individual fields out
/// if the result needs to cross an actor boundary.
public struct Wait6Result {
    /// PID of the child whose state changed, or 0 if `WNOHANG` was set
    /// and nothing was waiting.
    public let pid: pid_t

    /// Raw wait status word, suitable for `WIFEXITED`/`WEXITSTATUS`/etc.
    public let status: Int32

    /// Resource usage of the waited-for child itself.
    public let selfRusage: rusage

    /// Resource usage accumulated by the waited-for child's own children.
    public let childrenRusage: rusage

    /// Detailed signal-info record describing why the child changed state.
    public let signalInfo: siginfo_t
}

// MARK: - wait6(2)

/// Wait for a process state change with extended detail.
///
/// `wait6(2)` is a richer cousin of `waitpid(2)`/`wait4(2)`. Compared to
/// those it adds:
///
/// - explicit selection of which kind of identifier to match
///   (`pid`, `pgid`, `uid`, `jailID`, etc.)
/// - separate `rusage` for the child itself and for its descendants
/// - a full `siginfo_t` describing the state change
/// - explicit `WEXITED`/`WTRAPPED` opt-in
///
/// `wait6` does not implicitly wait for exited children: pass
/// `[.exited]` (or one of the other `W*` selectors) in `options`.
///
/// - Parameters:
///   - idType: Kind of identifier `id` selects.
///   - id: Identifier value (PID, PGID, UID, JID, …). Ignored when
///     `idType == .all`.
///   - options: Wait flags. Must include at least one of `.exited`,
///     `.untraced`, `.continued`, `.trapped`.
/// - Returns: A ``Wait6Result`` describing the child that changed state,
///   or `nil` if `.noHang` was set and no matching child was waiting.
/// - Throws: `BSDError` on failure (e.g. `ECHILD`).
public func wait6(
    idType: WaitIdType,
    id: id_t,
    options: WaitOptions
) throws -> Wait6Result? {
    var status: Int32 = 0
    var wru = __wrusage()
    var info = siginfo_t()

    let pid = Glibc.wait6(idType.rawValue, id, &status, options.rawValue, &wru, &info)
    if pid < 0 {
        try BSDError.throwErrno(errno)
    }
    if pid == 0 {
        // WNOHANG and nothing to report.
        return nil
    }

    return Wait6Result(
        pid: pid,
        status: status,
        selfRusage: wru.wru_self,
        childrenRusage: wru.wru_children,
        signalInfo: info
    )
}
