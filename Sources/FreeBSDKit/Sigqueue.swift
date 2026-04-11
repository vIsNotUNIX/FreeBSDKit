/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// Bind libc's sigqueue(3) directly. Swift's Glibc shim does not import
// it cleanly because `union sigval` has multiple compatibility members
// that the importer can't disambiguate.
@_silgen_name("sigqueue")
private func _sigqueue(_ pid: pid_t, _ signo: Int32, _ value: sigval) -> Int32

// MARK: - sigqueue(3)

/// Send a signal to a process along with a small integer payload.
///
/// `sigqueue(3)` is the POSIX real-time-signal cousin of `kill(2)`. The
/// extra `value` is delivered to the receiver as `siginfo_t.si_value`
/// when it handles the signal via `SA_SIGINFO` (or fetches it via
/// `sigwaitinfo`/`sigtimedwait`/`wait6`). This lets a sender attach one
/// 32-bit identifier to each signal — useful for distinguishing event
/// kinds without juggling separate signal numbers.
///
/// - Parameters:
///   - pid: Recipient process. Use `getpid()` to send to self.
///   - signal: Signal number to deliver. Real-time signals
///     (`SIGRTMIN..SIGRTMAX`) preserve `value` even when multiple are
///     queued; standard signals do not queue and only deliver the most
///     recent value.
///   - value: Integer payload, surfaced to the receiver as
///     `siginfo_t.si_value.sival_int`.
/// - Throws: `BSDError` on failure (e.g. `ESRCH`, `EPERM`, `EAGAIN` if
///   the per-process queue is full).
public func queueSignal(
    pid: pid_t,
    signal: Int32,
    value: Int32 = 0
) throws {
    var sv = sigval()
    sv.sival_int = value
    let r = _sigqueue(pid, signal, sv)
    if r != 0 {
        try BSDError.throwErrno(errno)
    }
}
