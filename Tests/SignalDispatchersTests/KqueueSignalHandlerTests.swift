/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import SignalDispatchers
@testable import Descriptors
@testable import FreeBSDKit

final class KqueueSignalHandlerTests: XCTestCase {

    func testBlockSignals() throws {
        // Test that blockSignals doesn't throw
        try SystemKqueueDescriptor.blockSignals([.usr1, .usr2])
    }

    func testRegisterSignal() throws {
        let kq = SystemKqueueDescriptor(kqueue())
        defer { kq.close() }

        // Register catchable signal
        try kq.registerSignal(.usr1)

        // Should not throw for catchable signals
        try kq.registerSignal(.usr2)
    }

    func testUnregisterSignal() throws {
        let kq = SystemKqueueDescriptor(kqueue())
        defer { kq.close() }

        // Register and unregister
        try kq.registerSignal(.usr1)
        try kq.unregisterSignal(.usr1)
    }

    func testRegisterNonCatchableSignalFails() throws {
        let kq = SystemKqueueDescriptor(kqueue())
        defer { kq.close() }

        // Attempting to register KILL or STOP should fail
        XCTAssertThrowsError(try kq.registerSignal(.kill))
        XCTAssertThrowsError(try kq.registerSignal(.stop))
    }

    func testNextSignalReceivesSignal() async throws {
        let kq = SystemKqueueDescriptor(kqueue())
        defer { kq.close() }

        // Block and register SIGUSR1
        try SystemKqueueDescriptor.blockSignals([.usr1])
        try kq.registerSignal(.usr1)

        // Send signal to self in background
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            kill(getpid(), SIGUSR1)
        }

        // Wait for signal with timeout
        let receivedSignal = try await withTimeout(seconds: 2) {
            try await kq.nextSignal(maxEvents: 8)
        }

        XCTAssertEqual(receivedSignal, .usr1)
    }

    func testKqueueSignalHandlerInit() throws {
        let kq = SystemKqueueDescriptor(kqueue())

        _ = try KqueueSignalHandler(
            kqueue: kq,
            signals: [.usr1, .usr2]
        )

        // Init should not throw - handler is now valid
    }

    func testKqueueSignalHandlerRegistration() async throws {
        let kq = SystemKqueueDescriptor(kqueue())

        let signalHandler = try KqueueSignalHandler(
            kqueue: kq,
            signals: [.usr1]
        )

        nonisolated(unsafe) var handlerCalled = false
        await signalHandler.on(.usr1) {
            handlerCalled = true
        }

        // Handler registration should not throw
        XCTAssertFalse(handlerCalled)
    }

    func testMultipleSignalsCanBeRegistered() throws {
        let kq = SystemKqueueDescriptor(kqueue())
        defer { kq.close() }

        let signals: [BSDSignal] = [.usr1, .usr2, .alrm, .term]

        for signal in signals {
            XCTAssertNoThrow(try kq.registerSignal(signal))
        }
    }

    func testSignalBlockingValidatesSignals() throws {
        // Should succeed with valid signals
        XCTAssertNoThrow(try SystemKqueueDescriptor.blockSignals([.usr1, .usr2]))

        // BSDSignal enum only has valid signals, so all should work
        XCTAssertNoThrow(try SystemKqueueDescriptor.blockSignals([.int, .term]))
    }
}

// Helper for async tests with timeout
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {}

// Concrete implementation for testing
struct SystemKqueueDescriptor: KqueueDescriptor {
    typealias RAWBSD = Int32
    private let fd: Int32

    init(_ fd: Int32) {
        self.fd = fd
    }

    consuming func close() {
        Glibc.close(fd)
    }

    consuming func take() -> Int32 {
        return fd
    }

    func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}
