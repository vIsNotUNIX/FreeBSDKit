/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit
import CTimerFD

// MARK: - Clock selection

/// Clocks accepted by `timerfd_create(2)`.
///
/// Only `realtime` is affected by `clock_settime(2)`/NTP step adjustments
/// — that is the only clock for which `.cancelOnSet` is meaningful.
public struct TimerFDClock: RawRepresentable, Sendable, Equatable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Wall-clock time. Affected by `clock_settime(2)` and NTP step
    /// adjustments; the only clock for which `.cancelOnSet` is
    /// meaningful.
    public static let realtime  = TimerFDClock(rawValue: Int32(CLOCK_REALTIME))

    /// Monotonic time since an unspecified starting point. Not affected
    /// by wall-clock changes.
    public static let monotonic = TimerFDClock(rawValue: Int32(CLOCK_MONOTONIC))
}

// MARK: - Creation flags

/// Flags for `timerfd_create(2)`.
public struct TimerFDFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Set the close-on-exec flag on the resulting descriptor.
    public static let closeOnExec = TimerFDFlags(rawValue: TFD_CLOEXEC)

    /// Open the descriptor in non-blocking mode. Reads on a non-blocking
    /// timerfd return `EAGAIN` instead of waiting when no expiration has
    /// occurred yet.
    public static let nonBlocking = TimerFDFlags(rawValue: TFD_NONBLOCK)
}

// MARK: - settime flags

/// Flags for `timerfd_settime(2)`.
public struct TimerFDSetFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Interpret the initial expiration as an absolute time on the
    /// timer's clock instead of a relative duration.
    public static let absoluteTime = TimerFDSetFlags(rawValue: TFD_TIMER_ABSTIME)

    /// Cancel the timer (returning `ECANCELED` on read) if the realtime
    /// clock is stepped while it is armed. Only meaningful for
    /// `TimerFDClock.realtime` paired with `.absoluteTime`.
    public static let cancelOnSet = TimerFDSetFlags(rawValue: TFD_TIMER_CANCEL_ON_SET)
}

// MARK: - TimerDescriptor protocol

/// A descriptor backed by `timerfd_create(2)`.
///
/// `timerfd` exposes a kernel timer as a regular file descriptor: each
/// expiration writes an 8-byte expiration count that any reader can pick
/// up via `read(2)`. The descriptor can be passed across processes,
/// monitored via kqueue (`EVFILT_READ`), or polled with `poll(2)` —
/// useful when integrating with code that expects a fd-shaped timer.
///
/// FreeBSDKit also provides timer support via `KqueueDescriptor`'s
/// `EVFILT_TIMER` filter, which is the more idiomatic BSD path; this type
/// exists for portability with code originally written against Linux.
public protocol TimerDescriptor: Descriptor, ~Copyable {

    /// Create a new timerfd.
    ///
    /// - Parameters:
    ///   - clock: Clock to drive the timer.
    ///   - flags: Creation flags.
    static func timerfd(clock: TimerFDClock, flags: TimerFDFlags) throws -> Self

    /// Arm or disarm the timer.
    ///
    /// - Parameters:
    ///   - initial: First expiration. A zero `timespec` disarms the timer.
    ///   - interval: Period for subsequent expirations. Zero means the
    ///     timer fires only once.
    ///   - flags: Set-time flags (e.g. `.absoluteTime`).
    /// - Returns: The previously-armed `(initial, interval)`.
    @discardableResult
    func setTime(
        initial: timespec,
        interval: timespec,
        flags: TimerFDSetFlags
    ) throws -> (initial: timespec, interval: timespec)

    /// Read the currently-armed `(initial, interval)` without modifying
    /// the timer.
    func currentTime() throws -> (initial: timespec, interval: timespec)

    /// Block until at least one expiration has occurred and return the
    /// number of expirations since the last read.
    ///
    /// On a non-blocking timerfd, throws `BSDError(.EAGAIN)` if no
    /// expiration is pending. Throws `BSDError(.ECANCELED)` if the timer
    /// was armed with `.cancelOnSet` and the realtime clock was stepped.
    func readExpirations() throws -> UInt64
}

// MARK: - Default implementations

public extension TimerDescriptor where Self: ~Copyable {

    static func timerfd(
        clock: TimerFDClock,
        flags: TimerFDFlags = [.closeOnExec]
    ) throws -> Self {
        let fd = CTimerFD.timerfd_create(clock.rawValue, flags.rawValue)
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(fd)
    }

    @discardableResult
    func setTime(
        initial: timespec,
        interval: timespec = timespec(tv_sec: 0, tv_nsec: 0),
        flags: TimerFDSetFlags = []
    ) throws -> (initial: timespec, interval: timespec) {
        var new = itimerspec(it_interval: interval, it_value: initial)
        var old = itimerspec(it_interval: timespec(tv_sec: 0, tv_nsec: 0),
                             it_value: timespec(tv_sec: 0, tv_nsec: 0))
        try self.unsafe { fd in
            guard CTimerFD.timerfd_settime(fd, flags.rawValue, &new, &old) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
        return (initial: old.it_value, interval: old.it_interval)
    }

    func currentTime() throws -> (initial: timespec, interval: timespec) {
        var current = itimerspec(it_interval: timespec(tv_sec: 0, tv_nsec: 0),
                                 it_value: timespec(tv_sec: 0, tv_nsec: 0))
        try self.unsafe { fd in
            guard CTimerFD.timerfd_gettime(fd, &current) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
        return (initial: current.it_value, interval: current.it_interval)
    }

    func readExpirations() throws -> UInt64 {
        var value: UInt64 = 0
        let n: Int = try self.unsafe { fd in
            withUnsafeMutablePointer(to: &value) { ptr in
                // Retry on EINTR. Other errors (EAGAIN on a non-blocking
                // timerfd, ECANCELED if .cancelOnSet fired) propagate to
                // the caller.
                while true {
                    let r = Glibc.read(fd, UnsafeMutableRawPointer(ptr), MemoryLayout<UInt64>.size)
                    if r >= 0 { return r }
                    if errno == EINTR { continue }
                    return r
                }
            }
        }
        if n < 0 {
            try BSDError.throwErrno(errno)
        }
        if n != MemoryLayout<UInt64>.size {
            throw BSDError.errno(EIO)
        }
        return value
    }
}
