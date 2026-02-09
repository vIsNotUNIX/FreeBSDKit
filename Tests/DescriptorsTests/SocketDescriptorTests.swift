/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import Descriptors

final class SocketDescriptorTests: XCTestCase {

    func testCreateSocket() throws {
        let sock = try SystemSocketDescriptor.socket(
            domain: .inet,
            type: .stream,
            protocol: .default
        )
        defer { sock.close() }

        // Verify socket was created
        let fd = sock.unsafe { $0 }
        XCTAssertGreaterThanOrEqual(fd, 0, "Socket creation failed")
    }

    func testBindAndListen() throws {
        let sock = try SystemSocketDescriptor.socket(
            domain: .inet,
            type: .stream,
            protocol: .default
        )
        defer { sock.close() }

        // Enable SO_REUSEADDR
        var reuseAddr: Int32 = 1
        _ = sock.unsafe { fd in
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        }

        // Bind to localhost with automatic port assignment (port 0 = any available port)
        let addr = IPv4SocketAddress(port: 0)
        try sock.bind(address: addr)

        // Listen should not throw
        try sock.listen(backlog: 5)
    }

    func testSocketPair() throws {
        let (sock1, sock2) = try SystemSocketDescriptor.socketPair(
            domain: .unix,
            type: .stream,
            protocol: .default
        )
        defer {
            sock1.close()
            sock2.close()
        }

        // Send data through sock1
        let testData = "Hello, Socket!".data(using: .utf8)!
        let written = try sock1.sendOnce(testData, flags: [])
        XCTAssertEqual(written, testData.count, "Write to socket failed")

        // Receive on sock2
        let recvResult = try sock2.recv(maxBytes: testData.count, flags: [])
        if case .data(let received) = recvResult {
            XCTAssertEqual(received, testData, "Read from socket failed")
        } else {
            XCTFail("Expected data, got EOF")
        }
    }

    func testShutdown() throws {
        let (sock1, sock2) = try SystemSocketDescriptor.socketPair(
            domain: .unix,
            type: .stream,
            protocol: .default
        )
        defer {
            sock1.close()
            sock2.close()
        }

        // Shutdown write on sock1
        try sock1.shutdown(how: .write)

        // sock2 should be able to read EOF
        let recvResult = try sock2.recv(maxBytes: 100, flags: [])
        if case .eof = recvResult {
            // Success - got EOF as expected
        } else {
            XCTFail("Expected EOF after shutdown")
        }
    }
}

// Concrete implementation for testing
struct SystemSocketDescriptor: SocketDescriptor {
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
