/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import BPC
import Capabilities
import Descriptors
import Foundation

// MARK: - Tests

final class BPCTests: XCTestCase {

    // MARK: - Message Struct

    func testMessageDefaults() {
        let msg = Message(id: .ping)
        XCTAssertEqual(msg.id, .ping)
        XCTAssertEqual(msg.correlationID, 0)
        XCTAssertTrue(msg.payload.isEmpty)
        XCTAssertTrue(msg.descriptors.isEmpty)
    }

    func testMessageFactories() {
        let req = Message.request(.lookup, payload: Data("hello".utf8))
        XCTAssertEqual(req.id, .lookup)
        XCTAssertEqual(req.correlationID, 0)  // endpoint assigns this on send
        XCTAssertEqual(req.payload, Data("hello".utf8))

        let note = Message.notification(.event)
        XCTAssertEqual(note.id, .event)
        XCTAssertEqual(note.correlationID, 0)
    }

    func testMessageIDRawValues() {
        XCTAssertEqual(MessageID.ping.rawValue,        1)
        XCTAssertEqual(MessageID.pong.rawValue,        2)
        XCTAssertEqual(MessageID.lookup.rawValue,      3)
        XCTAssertEqual(MessageID.lookupReply.rawValue, 4)
        XCTAssertEqual(MessageID.subscribe.rawValue,   5)
        XCTAssertEqual(MessageID.subscribeAck.rawValue,6)
        XCTAssertEqual(MessageID.event.rawValue,       7)
        XCTAssertEqual(MessageID.error.rawValue,       255)
    }

    // MARK: - Send / Reply

    func testRequest() async throws {
        let socketPath = "/tmp/bpc-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let listener = try BSDListener.unix(path: socketPath)

        // Server: accept one connection, receive ping, send pong
        let serverTask = Task {
            let server = try await listener.accept()
            await server.start()

            for await message in await server.messages {
                if message.id == .ping {
                    let pong = Message(
                        id: .pong,
                        correlationID: message.correlationID,
                        payload: message.payload
                    )
                    try await server.send(pong)
                }
                break  // handle one exchange
            }

            await server.stop()
        }

        // Give listener a moment to bind
        try await Task.sleep(nanoseconds: 50_000_000)

        // Client: connect, send ping, await pong
        let client = try BSDEndpoint.connect(path: socketPath)
        await client.start()

        let reply = try await client.request(.request(.ping, payload: Data("timestamp".utf8)))

        XCTAssertEqual(reply.id, .pong)
        XCTAssertEqual(reply.payload, Data("timestamp".utf8))

        await client.stop()
        await listener.stop()
        _ = await serverTask.result
    }

    // MARK: - Unsolicited messages

    func testUnsolicitedMessages() async throws {
        let socketPath = "/tmp/bpc-notif-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }

        let listener = try BSDListener.unix(path: socketPath)

        // Server: accept and push 3 events
        let serverTask = Task {
            let server = try await listener.accept()
            await server.start()

            for i in 0..<3 {
                let event = Message.notification(.event, payload: Data([UInt8(i)]))
                try await server.send(event)
            }

            await server.stop()
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        let client = try BSDEndpoint.connect(path: socketPath)
        await client.start()

        var received: [Message] = []
        for await message in await client.messages {
            received.append(message)
            if received.count == 3 { break }
        }

        XCTAssertEqual(received.count, 3)
        XCTAssertTrue(received.allSatisfy { $0.id == .event })
        XCTAssertEqual(received.map { $0.payload.first }, [0, 1, 2])

        await client.stop()
        await listener.stop()
        _ = await serverTask.result
    }
}
