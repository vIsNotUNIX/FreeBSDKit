/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - close_range(2)

/// Flags for `close_range(2)`.
public struct CloseRangeFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Set the close-on-exec flag on descriptors in the range instead of
    /// closing them.
    public static let cloexec = CloseRangeFlags(rawValue: Int32(CLOSE_RANGE_CLOEXEC))

    /// Set the close-on-fork flag on descriptors in the range instead of
    /// closing them.
    public static let clofork = CloseRangeFlags(rawValue: Int32(CLOSE_RANGE_CLOFORK))
}

/// Close (or modify) every open descriptor in `[low, high]` inclusive.
///
/// `close_range(2)` is the bulk equivalent of calling `close(2)` (or
/// `fcntl(F_SETFD, FD_CLOEXEC)`) on each descriptor in a range. It is the
/// preferred way for a child process to scrub inherited descriptors before
/// `execve(2)`. The kernel ignores descriptors that are not currently open
/// inside the requested range.
///
/// - Parameters:
///   - low: Lowest descriptor in the range.
///   - high: Highest descriptor in the range. Pass `UInt32.max` to mean
///     "every descriptor at or above `low`".
///   - flags: Use `.cloexec`/`.clofork` to mark descriptors instead of
///     closing them.
/// - Throws: `BSDError` on failure.
public func closeRange(
    low: UInt32,
    high: UInt32 = .max,
    flags: CloseRangeFlags = []
) throws {
    let r = Glibc.close_range(low, high, flags.rawValue)
    if r != 0 {
        try BSDError.throwErrno(errno)
    }
}
