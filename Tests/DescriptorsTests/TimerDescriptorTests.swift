/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
import FreeBSDKit
@testable import Descriptors

// MARK: - Test conformance

struct TestTimerDescriptor: TimerDescriptor {
    typealias RAWBSD = Int32
    private let fd: Int32

    init(_ fd: Int32) { self.fd = fd }
    consuming func close() { Glibc.close(fd) }
    consuming func take() -> Int32 { fd }
    func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

final class TimerDescriptorTests: XCTestCase {

    func testOneShotTimerFires() throws {
        let timer: TestTimerDescriptor = try .timerfd(clock: .monotonic)
        defer { timer.close() }

        // Fire once after 20 ms.
        try timer.setTime(
            initial: timespec(tv_sec: 0, tv_nsec: 20_000_000),
            interval: timespec(tv_sec: 0, tv_nsec: 0)
        )

        let expirations = try timer.readExpirations()
        XCTAssertEqual(expirations, 1)
    }

    func testRepeatingTimerAccumulatesExpirations() throws {
        let timer: TestTimerDescriptor = try .timerfd(clock: .monotonic)
        defer { timer.close() }

        // First expiration in 5 ms, then every 5 ms.
        try timer.setTime(
            initial: timespec(tv_sec: 0, tv_nsec: 5_000_000),
            interval: timespec(tv_sec: 0, tv_nsec: 5_000_000)
        )

        // Sleep ~30 ms — at least a handful of intervals should accumulate.
        var ts = timespec(tv_sec: 0, tv_nsec: 30_000_000)
        nanosleep(&ts, nil)

        let expirations = try timer.readExpirations()
        XCTAssertGreaterThanOrEqual(expirations, 2,
            "expected multiple expirations, got \(expirations)")
    }

    func testNonBlockingReturnsEAGAINBeforeFiring() throws {
        let timer: TestTimerDescriptor = try .timerfd(
            clock: .monotonic,
            flags: [.closeOnExec, .nonBlocking]
        )
        defer { timer.close() }

        // Arm well in the future so the read can't possibly succeed.
        try timer.setTime(
            initial: timespec(tv_sec: 60, tv_nsec: 0),
            interval: timespec(tv_sec: 0, tv_nsec: 0)
        )

        XCTAssertThrowsError(try timer.readExpirations()) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .EAGAIN)
        }
    }

    func testCurrentTimeReportsArmedState() throws {
        let timer: TestTimerDescriptor = try .timerfd(clock: .monotonic)
        defer { timer.close() }

        // Disarmed: it_value should be all-zero.
        var current = try timer.currentTime()
        XCTAssertEqual(current.initial.tv_sec, 0)
        XCTAssertEqual(current.initial.tv_nsec, 0)

        try timer.setTime(
            initial: timespec(tv_sec: 60, tv_nsec: 0),
            interval: timespec(tv_sec: 1, tv_nsec: 0)
        )

        current = try timer.currentTime()
        // it_value counts down toward zero; should be > 0 and ≤ 60s.
        XCTAssertGreaterThan(current.initial.tv_sec, 0)
        XCTAssertLessThanOrEqual(current.initial.tv_sec, 60)
        XCTAssertEqual(current.interval.tv_sec, 1)
    }

    func testSetTimeReturnsPreviousArming() throws {
        let timer: TestTimerDescriptor = try .timerfd(clock: .monotonic)
        defer { timer.close() }

        // Initial arm: 5 s + 1 s interval.
        let first = try timer.setTime(
            initial: timespec(tv_sec: 5, tv_nsec: 0),
            interval: timespec(tv_sec: 1, tv_nsec: 0)
        )
        // Previously disarmed.
        XCTAssertEqual(first.initial.tv_sec, 0)
        XCTAssertEqual(first.interval.tv_sec, 0)

        // Re-arm: should report the previous arming back.
        let second = try timer.setTime(
            initial: timespec(tv_sec: 10, tv_nsec: 0),
            interval: timespec(tv_sec: 2, tv_nsec: 0)
        )
        XCTAssertGreaterThan(second.initial.tv_sec, 0)
        XCTAssertLessThanOrEqual(second.initial.tv_sec, 5)
        XCTAssertEqual(second.interval.tv_sec, 1)
    }
}
