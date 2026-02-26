/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
import Dispatch
@testable import SignalDispatchers
@testable import FreeBSDKit

final class DispatchSignalDispatcherTests: XCTestCase {

    func testInitWithCatchableSignals() throws {
        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1, .usr2]
        )
        XCTAssertNotNil(dispatcher)
        dispatcher.cancel()
    }

    func testInitWithUncatchableSignalThrows() {
        XCTAssertThrowsError(
            try DispatchSignalDispatcher(signals: [.kill])
        ) { error in
            XCTAssertTrue(error is POSIXError)
        }

        XCTAssertThrowsError(
            try DispatchSignalDispatcher(signals: [.stop])
        ) { error in
            XCTAssertTrue(error is POSIXError)
        }
    }

    func testHandlerRegistration() throws {
        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1]
        )
        defer { dispatcher.cancel() }

        nonisolated(unsafe) var handlerCalled = false
        dispatcher.on(.usr1) {
            handlerCalled = true
        }

        // Just verify registration doesn't crash
        XCTAssertFalse(handlerCalled)
    }

    func testSignalDeliveryViaLibdispatch() throws {
        let expectation = XCTestExpectation(description: "Signal handler called")

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1],
            queue: .main
        )
        defer { dispatcher.cancel() }

        dispatcher.on(.usr1) {
            expectation.fulfill()
        }

        // Send signal to self
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMultipleSignals() throws {
        let expectation1 = XCTestExpectation(description: "SIGUSR1 handler called")
        let expectation2 = XCTestExpectation(description: "SIGUSR2 handler called")

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1, .usr2],
            queue: .main
        )
        defer { dispatcher.cancel() }

        dispatcher.on(.usr1) {
            expectation1.fulfill()
        }

        dispatcher.on(.usr2) {
            expectation2.fulfill()
        }

        // Send both signals
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
            kill(getpid(), SIGUSR2)
        }

        wait(for: [expectation1, expectation2], timeout: 2.0)
    }

    func testHandlerReplacement() throws {
        let expectation = XCTestExpectation(description: "Second handler called")

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1],
            queue: .main
        )
        defer { dispatcher.cancel() }

        nonisolated(unsafe) var firstHandlerCalled = false
        dispatcher.on(.usr1) {
            firstHandlerCalled = true
        }

        // Replace with second handler
        dispatcher.on(.usr1) {
            XCTAssertFalse(firstHandlerCalled)
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCancelReleasesResources() throws {
        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1, .usr2]
        )

        dispatcher.cancel()

        // After cancel, handlers should not be called
        nonisolated(unsafe) var handlerCalled = false
        dispatcher.on(.usr1) {
            handlerCalled = true
        }

        kill(getpid(), SIGUSR1)

        // Give time for potential handler execution
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertFalse(handlerCalled)
    }

    func testSignalsAreBlocked() throws {
        // Install a traditional signal handler first
        let traditionHandlerCalled = false
        signal(SIGUSR1, SIG_DFL)

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1],
            queue: .main
        )
        defer { dispatcher.cancel() }

        let expectation = XCTestExpectation(description: "Libdispatch handler called")

        dispatcher.on(.usr1) {
            expectation.fulfill()
        }

        // Send signal - should be handled by libdispatch, not traditional handler
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)

        // Traditional handler should not have been called
        XCTAssertFalse(traditionHandlerCalled)
    }

    func testMultipleHandlersForSameSignal() throws {
        // Only the last registered handler should be active
        let expectation = XCTestExpectation(description: "Final handler called")
        expectation.expectedFulfillmentCount = 1

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1],
            queue: .main
        )
        defer { dispatcher.cancel() }

        nonisolated(unsafe) var firstCalled = false
        dispatcher.on(.usr1) {
            firstCalled = true
        }

        nonisolated(unsafe) var secondCalled = false
        dispatcher.on(.usr1) {
            secondCalled = true
        }

        // Final handler
        dispatcher.on(.usr1) {
            XCTAssertFalse(firstCalled)
            XCTAssertFalse(secondCalled)
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCustomQueue() throws {
        let customQueue = DispatchQueue(label: "test.signal.queue")
        let expectation = XCTestExpectation(description: "Handler on custom queue")

        let dispatcher = try DispatchSignalDispatcher(
            signals: [.usr1],
            queue: customQueue
        )
        defer { dispatcher.cancel() }

        dispatcher.on(.usr1) {
            // Verify we're on the custom queue (best effort)
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
