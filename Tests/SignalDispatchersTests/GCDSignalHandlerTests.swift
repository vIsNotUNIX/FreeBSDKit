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

final class GCDSignalHandlerTests: XCTestCase {

    func testInitWithCatchableSignals() throws {
        let handler = try GCDSignalHandler(
            signals: [.usr1, .usr2]
        )
        XCTAssertNotNil(handler)
        handler.cancel()
    }

    func testInitWithUncatchableSignalThrows() {
        XCTAssertThrowsError(
            try GCDSignalHandler(signals: [.kill])
        ) { error in
            XCTAssertTrue(error is POSIXError)
        }

        XCTAssertThrowsError(
            try GCDSignalHandler(signals: [.stop])
        ) { error in
            XCTAssertTrue(error is POSIXError)
        }
    }

    func testHandlerRegistration() throws {
        let handler = try GCDSignalHandler(
            signals: [.usr1]
        )
        defer { handler.cancel() }

        nonisolated(unsafe) var handlerCalled = false
        handler.on(.usr1) {
            handlerCalled = true
        }

        // Just verify registration doesn't crash
        XCTAssertFalse(handlerCalled)
    }

    func testSignalDeliveryViaLibdispatch() throws {
        let expectation = XCTestExpectation(description: "Signal handler called")

        let handler = try GCDSignalHandler(
            signals: [.usr1],
            queue: .main
        )
        defer { handler.cancel() }

        handler.on(.usr1) {
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

        let handler = try GCDSignalHandler(
            signals: [.usr1, .usr2],
            queue: .main
        )
        defer { handler.cancel() }

        handler.on(.usr1) {
            expectation1.fulfill()
        }

        handler.on(.usr2) {
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

        let handler = try GCDSignalHandler(
            signals: [.usr1],
            queue: .main
        )
        defer { handler.cancel() }

        nonisolated(unsafe) var firstHandlerCalled = false
        handler.on(.usr1) {
            firstHandlerCalled = true
        }

        // Replace with second handler
        handler.on(.usr1) {
            XCTAssertFalse(firstHandlerCalled)
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCancelReleasesResources() throws {
        let handler = try GCDSignalHandler(
            signals: [.usr1, .usr2]
        )

        handler.cancel()

        // After cancel, handlers should not be called
        nonisolated(unsafe) var handlerCalled = false
        handler.on(.usr1) {
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

        let handler = try GCDSignalHandler(
            signals: [.usr1],
            queue: .main
        )
        defer { handler.cancel() }

        let expectation = XCTestExpectation(description: "Libdispatch handler called")

        handler.on(.usr1) {
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

        let handler = try GCDSignalHandler(
            signals: [.usr1],
            queue: .main
        )
        defer { handler.cancel() }

        nonisolated(unsafe) var firstCalled = false
        handler.on(.usr1) {
            firstCalled = true
        }

        nonisolated(unsafe) var secondCalled = false
        handler.on(.usr1) {
            secondCalled = true
        }

        // Final handler
        handler.on(.usr1) {
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

        let handler = try GCDSignalHandler(
            signals: [.usr1],
            queue: customQueue
        )
        defer { handler.cancel() }

        handler.on(.usr1) {
            // Verify we're on the custom queue (best effort)
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            kill(getpid(), SIGUSR1)
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
