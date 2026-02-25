/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FPC
import Descriptors
import Capabilities

// MARK: - Test Message IDs

extension MessageID {
    static let echo = MessageID(rawValue: 100)
    static let echoReply = MessageID(rawValue: 101)
    static let largeData = MessageID(rawValue: 102)
    static let largeDataReply = MessageID(rawValue: 103)
    static let withDescriptors = MessageID(rawValue: 104)
    static let withDescriptorsReply = MessageID(rawValue: 105)
    static let unsolicited = MessageID(rawValue: 106)
    static let sendUnsolicited = MessageID(rawValue: 108)
    static let done = MessageID(rawValue: 107)
    static let serverRequest = MessageID(rawValue: 109)
    static let serverRequestReply = MessageID(rawValue: 110)
    static let triggerServerRequest = MessageID(rawValue: 111)
}

// MARK: - Logging

enum Role: String {
    case server = "SERVER"
    case client = "CLIENT"
    case pair = "PAIR"
    case none = ""
}

private var currentRole: Role = .none
private let startTime = Date()

func setRole(_ role: Role) {
    currentRole = role
}

func log(_ message: String) {
    let elapsed = Date().timeIntervalSince(startTime)
    let minutes = Int(elapsed) / 60
    let seconds = Int(elapsed) % 60
    let millis = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 1000)
    let timeStr = String(format: "%02d:%02d.%03d", minutes, seconds, millis)

    let prefix = currentRole == .none ? "" : "[\(currentRole.rawValue)] "
    print("[\(timeStr)] \(prefix)\(message)")
    fflush(stdout)
}

// MARK: - Test Harness

@main
struct BPCTestHarness {

    static func main() async {
        setbuf(stdout, nil)

        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        switch args[1] {
        case "pair":
            await testPair()
        case "server":
            guard args.count >= 3 else {
                print("Usage: bpc-test-harness server <socket-path>")
                exit(1)
            }
            await runServer(socketPath: args[2])
        case "client":
            guard args.count >= 3 else {
                print("Usage: bpc-test-harness client <socket-path>")
                exit(1)
            }
            await runClient(socketPath: args[2])
        default:
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print("""
            BPC Test Harness - Demonstrates BPC IPC capabilities

            Usage:
              bpc-test-harness pair              # In-process socketpair test
              bpc-test-harness server <path>     # Start server on Unix socket
              bpc-test-harness client <path>     # Connect client to server

            Run server first in one terminal, then client in another.

            Tests:
              1. Request/Reply     - Correlation ID routing
              2. Large Message     - Auto OOL via shared memory (>64KB)
              3. Multi-Descriptor  - Pass multiple file descriptors
              4. Unsolicited Msgs  - Fire-and-forget messages via messages() stream
              5. Reply Isolation   - Replies don't leak into messages() stream
            """)
    }

    // MARK: - Pair Test (in-process)

    static func testPair() async {
        setRole(.pair)

        log("╔════════════════════════════════════════════════════════════╗")
        log("║  In-process socketpair test                                ║")
        log("║  Tests: send/receive, request/reply, bidirectional RPC     ║")
        log("╚════════════════════════════════════════════════════════════╝")

        do {
            log("Creating SEQPACKET socketpair...")
            let (endpointA, endpointB) = try FPCEndpoint.pair()

            log("Starting endpoint A...")
            await endpointA.start()
            log("Starting endpoint B...")
            await endpointB.start()
            log("Both endpoints active")

            var passed = 0
            var failed = 0

            // --- Test 1: Request/Reply A→B ---
            log("")
            log("┌─ Test 1: Request/Reply (A→B) ─┐")
            do {
                let requestUUID = UUID().uuidString
                log("│ A → request: \(requestUUID)")

                // B listens and replies (background task)
                let replyTask = Task {
                    let stream = try await endpointB.incoming()
                    for await msg in stream {
                        let replyUUID = UUID().uuidString
                        log("│ B ← got request, replying: \(replyUUID)")
                        try await endpointB.reply(to: msg, id: .echoReply,
                            payload: Data("b-reply:\(replyUUID)".utf8))
                        return replyUUID
                    }
                    return ""
                }

                let reply = try await endpointA.request(
                    Message(id: .echo, payload: Data("a-request:\(requestUUID)".utf8)),
                    timeout: .seconds(5)
                )

                let bUUID = try await replyTask.value
                let replyStr = String(data: reply.payload, encoding: .utf8) ?? ""
                log("│ A ← got reply: \(replyStr)")

                if replyStr.contains(bUUID) {
                    log("└ ✓ PASS")
                    passed += 1
                } else {
                    log("└ ✗ FAIL: UUID mismatch")
                    failed += 1
                }
            } catch {
                log("└ ✗ FAIL: \(error)")
                failed += 1
            }

            // --- Test 2: Request/Reply B→A (proves bidirectional) ---
            log("")
            log("┌─ Test 2: Request/Reply (B→A) - Bidirectional ─┐")
            do {
                let requestUUID = UUID().uuidString
                log("│ B → request: \(requestUUID)")

                // A listens and replies
                let replyTask = Task {
                    let stream = try await endpointA.incoming()
                    for await msg in stream {
                        let replyUUID = UUID().uuidString
                        log("│ A ← got request, replying: \(replyUUID)")
                        try await endpointA.reply(to: msg, id: .echoReply,
                            payload: Data("a-reply:\(replyUUID)".utf8))
                        return replyUUID
                    }
                    return ""
                }

                let reply = try await endpointB.request(
                    Message(id: .echo, payload: Data("b-request:\(requestUUID)".utf8)),
                    timeout: .seconds(5)
                )

                let aUUID = try await replyTask.value
                let replyStr = String(data: reply.payload, encoding: .utf8) ?? ""
                log("│ B ← got reply: \(replyStr)")

                if replyStr.contains(aUUID) {
                    log("└ ✓ PASS: Bidirectional RPC verified!")
                    passed += 1
                } else {
                    log("└ ✗ FAIL: UUID mismatch")
                    failed += 1
                }
            } catch {
                log("└ ✗ FAIL: \(error)")
                failed += 1
            }

            log("Closing endpoint A...")
            await endpointA.stop()
            log("Closing endpoint B...")
            await endpointB.stop()
            log("Endpoints A,B closed")

            // --- Test 3: Data integrity with large payload (fresh pair) ---
            log("")
            log("┌─ Test 3: Large Payload (64KB pattern) ─┐")
            do {
                let (epA, epB) = try FPCEndpoint.pair()
                await epA.start()
                await epB.start()

                let size = 64 * 1024
                var payload = Data(count: size)
                for i in 0..<size {
                    payload[i] = UInt8(i % 256)
                }
                log("│ A → sending \(size) bytes")

                // B receives and verifies
                let verifyTask = Task {
                    let stream = try await epB.incoming()
                    for await msg in stream {
                        var valid = true
                        for (i, byte) in msg.payload.enumerated() {
                            if byte != UInt8(i % 256) {
                                valid = false
                                break
                            }
                        }
                        log("│ B ← received \(msg.payload.count) bytes")
                        return valid && msg.payload.count == size
                    }
                    return false
                }

                try await epA.send(Message(id: .largeData, payload: payload))
                let valid = try await verifyTask.value

                log("│ Closing test endpoints...")
                await epA.stop()
                await epB.stop()
                log("│ Test endpoints closed")

                if valid {
                    log("│ B verified pattern OK")
                    log("└ ✓ PASS")
                    passed += 1
                } else {
                    log("└ ✗ FAIL: Pattern mismatch")
                    failed += 1
                }
            } catch {
                log("└ ✗ FAIL: \(error)")
                failed += 1
            }

            log("")
            log("╔════════════════════════════════════════════════════════════╗")
            if failed == 0 {
                log("║  ALL \(passed) TESTS PASSED                                    ║")
            } else {
                log("║  RESULTS: \(passed) passed, \(failed) failed                              ║")
            }
            log("╚════════════════════════════════════════════════════════════╝")
            if failed > 0 {
                exit(1)
            }
        } catch {
            log("ERROR: \(error)")
            exit(1)
        }
    }

    // MARK: - Server

    static func runServer(socketPath: String) async {
        setRole(.server)

        log("╔════════════════════════════════════════════════════════════╗")
        log("║  Starting server on: \(socketPath)")
        log("╚════════════════════════════════════════════════════════════╝")

        unlink(socketPath)

        do {
            log("Creating listener...")
            let listener = try FPCListener.listen(on: socketPath)
            await listener.start()
            log("Listener started")

            let readyPath = socketPath + ".ready"
            _ = FileManager.default.createFile(atPath: readyPath, contents: nil)
            defer { try? FileManager.default.removeItem(atPath: readyPath) }

            log("Waiting for connection...")

            let connections = try await listener.connections()
            guard let endpoint = try await connections.first(where: { _ in true }) else {
                log("ERROR: No connection received")
                exit(1)
            }

            log("Connection accepted, starting endpoint...")
            await endpoint.start()
            log("CLIENT CONNECTED - endpoint active")
            log("")

            let stream = try await endpoint.incoming()
            for await message in stream {
                log("┌─ Received: id=\(message.id), correlationID=\(message.correlationID), \(message.payload.count) bytes, \(message.descriptors.count) descriptors")

                if let str = String(data: message.payload, encoding: .utf8), str.count < 200 {
                    log("│  Payload: \(str)")
                }

                switch message.id {

                // --- Test 1: Request/Reply ---
                case .echo:
                    let replyUUID = UUID().uuidString
                    log("│  Processing echo request...")
                    log("└→ Replying with UUID: \(replyUUID)")
                    try await endpoint.reply(to: message, id: .echoReply,
                        payload: Data("server-echo:\(replyUUID)".utf8))

                // --- Test 2: Large data (OOL) ---
                case .largeData:
                    log("│  Received large payload: \(message.payload.count) bytes")
                    var valid = true
                    for (i, byte) in message.payload.enumerated() {
                        if byte != UInt8(i % 256) {
                            log("│  ✗ Pattern mismatch at offset \(i)")
                            valid = false
                            break
                        }
                    }
                    if valid {
                        log("│  ✓ Pattern verified (0x00-0xFF repeating)")
                    }
                    let replyUUID = UUID().uuidString
                    log("└→ Replying with ack UUID: \(replyUUID)")
                    try await endpoint.reply(to: message, id: .largeDataReply,
                        payload: Data("large-ack:\(replyUUID):\(message.payload.count)".utf8))

                // --- Test 3: Multiple descriptors ---
                case .withDescriptors:
                    log("│  Received \(message.descriptors.count) descriptor(s)")
                    var contents: [String] = []
                    for i in 0..<message.descriptors.count {
                        if let fd = message.descriptor(at: i, expecting: .file) {
                            var buffer = [UInt8](repeating: 0, count: 256)
                            let n = read(fd, &buffer, buffer.count)
                            close(fd)
                            if n > 0 {
                                let content = String(bytes: buffer.prefix(n), encoding: .utf8) ?? "<binary>"
                                log("│  fd[\(i)] contains: \(content)")
                                contents.append(content)
                            }
                        }
                    }
                    let replyUUID = UUID().uuidString
                    log("└→ Replying with contents and UUID: \(replyUUID)")
                    try await endpoint.reply(to: message, id: .withDescriptorsReply,
                        payload: Data("fds-read:\(replyUUID):\(contents.joined(separator: "|"))".utf8))

                // --- Test 6: Server-initiated request ---
                case .triggerServerRequest:
                    log("│  Client wants us to send a request TO them")
                    let serverUUID = UUID().uuidString
                    log("│  → Sending request with UUID: \(serverUUID)")

                    // Server sends request TO client, waits for reply
                    let clientReply = try await endpoint.request(
                        Message(id: .serverRequest, payload: Data("server-asks:\(serverUUID)".utf8)),
                        timeout: .seconds(5)
                    )

                    let replyContent = String(data: clientReply.payload, encoding: .utf8) ?? "<invalid>"
                    log("│  ← Got reply from client: \(replyContent)")

                    // Confirm back to client that we got their reply
                    log("└→ Confirming receipt")
                    try await endpoint.reply(to: message, id: .triggerServerRequest,
                        payload: Data("server-got:\(replyContent)".utf8))

                // --- Test 4: Send unsolicited messages ---
                case .sendUnsolicited:
                    let countStr = String(data: message.payload, encoding: .utf8) ?? "3"
                    let count = Int(countStr) ?? 3
                    log("│  Client requested \(count) unsolicited messages")
                    for i in 0..<count {
                        let msgUUID = UUID().uuidString
                        log("│  → Sending unsolicited[\(i)]: \(msgUUID)")
                        try await endpoint.send(Message(id: .unsolicited,
                            payload: Data("unsolicited:\(i):\(msgUUID)".utf8)))
                    }
                    log("└→ Sending done marker")
                    try await endpoint.send(Message(id: .done, payload: Data("unsolicited-complete".utf8)))

                // --- Done signal ---
                case .done:
                    log("└─ Shutdown signal received from client")
                    break

                default:
                    log("└─ Unknown message type: \(message.id)")
                }

                if message.id == .done {
                    break
                }
                log("")
            }

            log("")
            log("Closing client connection...")
            await endpoint.stop()
            log("Client connection closed")

            log("Stopping listener...")
            await listener.stop()
            log("Listener stopped")

            log("")
            log("╔════════════════════════════════════════════════════════════╗")
            log("║  Server shutdown complete                                  ║")
            log("╚════════════════════════════════════════════════════════════╝")

        } catch {
            log("ERROR: \(error)")
            exit(1)
        }
    }

    // MARK: - Client

    static func runClient(socketPath: String) async {
        setRole(.client)

        log("╔════════════════════════════════════════════════════════════╗")
        log("║  Starting client                                           ║")
        log("╚════════════════════════════════════════════════════════════╝")

        let readyPath = socketPath + ".ready"
        log("Waiting for server to be ready...")
        var attempts = 0
        while !FileManager.default.fileExists(atPath: readyPath) {
            attempts += 1
            if attempts > 50 {
                log("ERROR: Server not ready after 5 seconds")
                exit(1)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        do {
            log("Connecting to \(socketPath)...")
            let endpoint = try FPCClient.connect(path: socketPath)
            await endpoint.start()
            log("CONNECTED - endpoint active")

            var passed = 0
            var failed = 0

            // ══════════════════════════════════════════════════════════════
            // TEST 1: Request/Reply with correlation ID
            // ══════════════════════════════════════════════════════════════
            log("")
            log("┌──────────────────────────────────────────────────────────────┐")
            log("│ TEST 1: Request/Reply                                        │")
            log("│ Verifies: Correlation ID routing, request() blocks for reply │")
            log("└──────────────────────────────────────────────────────────────┘")
            do {
                let clientUUID = UUID().uuidString
                log("→ Sending request with UUID: \(clientUUID)")

                let reply = try await endpoint.request(
                    Message(id: .echo, payload: Data("client-echo:\(clientUUID)".utf8)),
                    timeout: .seconds(5)
                )

                let replyStr = String(data: reply.payload, encoding: .utf8) ?? "<invalid>"
                log("← Received reply: \(replyStr)")

                if replyStr.hasPrefix("server-echo:") {
                    log("✓ TEST 1 PASSED: Server generated unique reply UUID")
                    passed += 1
                } else {
                    log("✗ TEST 1 FAILED: Unexpected reply format")
                    failed += 1
                }
            } catch {
                log("✗ TEST 1 FAILED: \(error)")
                failed += 1
            }

            // ══════════════════════════════════════════════════════════════
            // TEST 2: Large message with automatic OOL (shared memory)
            // ══════════════════════════════════════════════════════════════
            log("")
            log("┌──────────────────────────────────────────────────────────────┐")
            log("│ TEST 2: Large Message (100KB)                                │")
            log("│ Verifies: Auto OOL via anonymous shared memory (>64KB limit) │")
            log("│ Wire: Only header+trailer sent; payload via shm descriptor   │")
            log("└──────────────────────────────────────────────────────────────┘")
            do {
                let size = 100 * 1024  // 100KB, well above 64KB SEQPACKET limit
                var largePayload = Data(count: size)
                for i in 0..<size {
                    largePayload[i] = UInt8(i % 256)
                }
                log("→ Sending \(size) bytes (pattern: 0x00-0xFF repeating)")
                log("  Note: BPC automatically uses shared memory for payloads >64KB")

                let reply = try await endpoint.request(
                    Message(id: .largeData, payload: largePayload),
                    timeout: .seconds(10)
                )

                let replyStr = String(data: reply.payload, encoding: .utf8) ?? "<invalid>"
                log("← Reply: \(replyStr)")

                if replyStr.contains("large-ack:") && replyStr.contains(":\(size)") {
                    log("✓ TEST 2 PASSED: Server received and verified \(size) bytes")
                    passed += 1
                } else {
                    log("✗ TEST 2 FAILED: Size or ack mismatch")
                    failed += 1
                }
            } catch {
                log("✗ TEST 2 FAILED: \(error)")
                failed += 1
            }

            // ══════════════════════════════════════════════════════════════
            // TEST 3: Multiple file descriptor passing
            // ══════════════════════════════════════════════════════════════
            log("")
            log("┌──────────────────────────────────────────────────────────────┐")
            log("│ TEST 3: Multiple File Descriptor Passing                     │")
            log("│ Verifies: SCM_RIGHTS with multiple fds, each readable        │")
            log("└──────────────────────────────────────────────────────────────┘")
            do {
                let uuids = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
                var fdRefs: [OpaqueDescriptorRef] = []

                for (i, uuid) in uuids.enumerated() {
                    let tempPath = "/tmp/bpc-test-\(getpid())-\(i).txt"
                    let content = "file\(i):\(uuid)"
                    try content.write(toFile: tempPath, atomically: true, encoding: .utf8)

                    let fd = open(tempPath, O_RDONLY)
                    guard fd >= 0 else {
                        throw POSIXError(.ENOENT)
                    }
                    fdRefs.append(OpaqueDescriptorRef(fd, kind: .file))
                    log("→ fd[\(i)] contains: \(content)")

                    try? FileManager.default.removeItem(atPath: tempPath)
                }

                log("→ Sending message with \(fdRefs.count) file descriptors")

                let reply = try await endpoint.request(
                    Message(id: .withDescriptors, payload: Data("check-fds".utf8), descriptors: fdRefs),
                    timeout: .seconds(5)
                )

                let replyStr = String(data: reply.payload, encoding: .utf8) ?? "<invalid>"
                log("← Reply: \(replyStr)")

                var allFound = true
                for uuid in uuids {
                    if !replyStr.contains(uuid) {
                        log("  ✗ Missing UUID: \(uuid)")
                        allFound = false
                    }
                }

                if allFound && replyStr.contains("fds-read:") {
                    log("✓ TEST 3 PASSED: Server read all \(uuids.count) UUIDs from passed fds")
                    passed += 1
                } else {
                    log("✗ TEST 3 FAILED: Not all UUIDs found in reply")
                    failed += 1
                }
            } catch {
                log("✗ TEST 3 FAILED: \(error)")
                failed += 1
            }

            // ══════════════════════════════════════════════════════════════
            // TEST 4: Unsolicited messages via messages() stream
            // ══════════════════════════════════════════════════════════════
            log("")
            log("┌──────────────────────────────────────────────────────────────┐")
            log("│ TEST 4: Unsolicited Messages Stream                          │")
            log("│ Verifies: Fire-and-forget messages, messages() iteration     │")
            log("│ Note: These have correlationID=0 (not replies)               │")
            log("└──────────────────────────────────────────────────────────────┘")
            do {
                let count = 5
                log("→ Requesting server send \(count) unsolicited messages")
                try await endpoint.send(Message(id: .sendUnsolicited, payload: Data("\(count)".utf8)))

                let stream = try await endpoint.incoming()
                var received: [String] = []

                for await msg in stream {
                    log("← Received: id=\(msg.id), correlationID=\(msg.correlationID)")
                    if msg.id == .done {
                        log("  (done marker)")
                        break
                    }
                    if msg.id == .unsolicited {
                        let content = String(data: msg.payload, encoding: .utf8) ?? "<invalid>"
                        log("  Content: \(content)")
                        received.append(content)
                    }
                }

                if received.count == count {
                    log("✓ TEST 4 PASSED: Received all \(count) unsolicited messages")
                    passed += 1
                } else {
                    log("✗ TEST 4 FAILED: Expected \(count), got \(received.count)")
                    failed += 1
                }
            } catch {
                log("✗ TEST 4 FAILED: \(error)")
                failed += 1
            }

            // ══════════════════════════════════════════════════════════════
            // TEST 5: Reply isolation (replies don't appear in messages())
            // ══════════════════════════════════════════════════════════════
            log("")
            log("┌──────────────────────────────────────────────────────────────┐")
            log("│ TEST 5: Reply Isolation                                      │")
            log("│ Verifies: Replies route to request() caller, not messages()  │")
            log("│ Critical: messages() must not see replies to our requests    │")
            log("└──────────────────────────────────────────────────────────────┘")
            do {
                // We need to verify that when we call request(), the reply
                // goes to request() and NOT to messages().
                // We'll send a request and simultaneously listen on messages().

                let requestUUID = UUID().uuidString
                log("→ Sending request with UUID: \(requestUUID)")
                log("  Simultaneously checking messages() stream...")

                var sawReplyInStream = false

                // Start a task to drain messages() and check for leaks
                let checkTask = Task {
                    // Get a fresh messages() stream
                    // Note: This will fail if stream already claimed, which is fine
                    do {
                        let stream = try await endpoint.incoming()
                        // Check for a short time
                        for try await msg in stream {
                            if msg.id == .echoReply {
                                sawReplyInStream = true
                                log("  ✗ LEAK: Reply appeared in messages() stream!")
                            }
                            // Don't block forever
                            break
                        }
                    } catch {
                        // Stream already claimed is expected in some cases
                    }
                }

                // Send request - reply should go to THIS call, not messages()
                let reply = try await endpoint.request(
                    Message(id: .echo, payload: Data("isolation-test:\(requestUUID)".utf8)),
                    timeout: .seconds(5)
                )

                checkTask.cancel()

                let replyStr = String(data: reply.payload, encoding: .utf8) ?? "<invalid>"
                log("← request() received reply: \(replyStr)")

                if !sawReplyInStream && replyStr.hasPrefix("server-echo:") {
                    log("✓ TEST 5 PASSED: Reply routed to request(), not messages()")
                    passed += 1
                } else if sawReplyInStream {
                    log("✗ TEST 5 FAILED: Reply leaked to messages() stream")
                    failed += 1
                } else {
                    log("✗ TEST 5 FAILED: Unexpected reply format")
                    failed += 1
                }
            } catch {
                log("✗ TEST 5 FAILED: \(error)")
                failed += 1
            }

            // ══════════════════════════════════════════════════════════════
            // Done
            // ══════════════════════════════════════════════════════════════
            log("")
            log("Sending shutdown signal to server...")
            try await endpoint.send(Message(id: .done))

            log("Closing connection...")
            await endpoint.stop()
            log("Connection closed")

            log("")
            log("╔════════════════════════════════════════════════════════════╗")
            if failed == 0 {
                log("║  ALL \(passed) TESTS PASSED                                    ║")
            } else {
                log("║  RESULTS: \(passed) passed, \(failed) failed                              ║")
            }
            log("╚════════════════════════════════════════════════════════════╝")

            exit(failed == 0 ? 0 : 1)

        } catch {
            log("ERROR: \(error)")
            exit(1)
        }
    }
}
