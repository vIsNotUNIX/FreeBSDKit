/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import DTraceCore
import Foundation
import Glibc

// MARK: - Periodic snapshot stream

extension DTraceSession {

    /// Repeatedly snapshot this session and invoke `body` with each
    /// row set, on the calling task, until cancelled or the
    /// `iterations` limit is reached.
    ///
    /// This is the streaming counterpart to ``snapshot(sorted:)``.
    /// `DTraceSession` is `~Copyable` and so cannot be captured inside
    /// an `AsyncStream` continuation; instead, this method runs the
    /// loop directly on the current task, sleeping between iterations
    /// and handing the closure a fresh snapshot each time. Cancellation
    /// is honored via `Task.checkCancellation()` between iterations.
    ///
    /// ```swift
    /// var session = try DTraceSession.create()
    /// session.add { … }
    /// try session.start()
    ///
    /// try await session.streamSnapshots(every: 1.0, iterations: 10) { records in
    ///     // Called on the current task once per second, ten times.
    ///     print(records.count, "rows")
    /// }
    ///
    /// try session.stop()
    /// ```
    ///
    /// - Parameters:
    ///   - interval: Seconds between snapshots. Must be > 0.
    ///   - iterations: Maximum number of snapshots, or `nil` for an
    ///     unbounded loop (cancellation only).
    ///   - sorted: Walk each snapshot in sorted order.
    ///   - body: Receives one snapshot per iteration. May throw to
    ///     stop the loop early.
    /// - Throws: Cancellation errors, snapshot errors from
    ///   `DTraceSession.snapshot`, or whatever `body` throws.
    public func streamSnapshots(
        every interval: TimeInterval,
        iterations: Int? = nil,
        sorted: Bool = true,
        _ body: ([AggregationRecord]) throws -> Void
    ) async throws {
        var iter = 0
        let nanoseconds = UInt64(interval * 1_000_000_000)
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: nanoseconds)
            try Task.checkCancellation()
            let snap = try snapshot(sorted: sorted)
            try body(snap)
            iter += 1
            if let limit = iterations, iter >= limit {
                break
            }
        }
    }
}
