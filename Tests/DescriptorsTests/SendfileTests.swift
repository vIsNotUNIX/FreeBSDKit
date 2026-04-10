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

final class SendfileTests: XCTestCase {

    // MARK: - Helpers

    /// Create a temp file containing `contents` and return (path, read-only fd).
    private func makeTempFile(contents: Data) throws -> (path: String, fd: Int32) {
        let path = "/tmp/freebsdkit-sendfile-\(getpid())-\(arc4random()).bin"
        let wfd = Glibc.open(path, O_CREAT | O_WRONLY | O_TRUNC, 0o600)
        guard wfd >= 0 else { throw POSIXError(.EIO) }
        let written = contents.withUnsafeBytes { buf -> Int in
            Glibc.write(wfd, buf.baseAddress, buf.count)
        }
        Glibc.close(wfd)
        guard written == contents.count else { throw POSIXError(.EIO) }

        let rfd = Glibc.open(path, O_RDONLY)
        guard rfd >= 0 else {
            Glibc.unlink(path)
            throw POSIXError(.EIO)
        }
        return (path, rfd)
    }

    /// Build a connected TCP pair on 127.0.0.1.
    /// Returns (server, client) — both are stream sockets connected to each other.
    private func makeConnectedTCPPair() throws -> (server: SystemSocketDescriptor, client: SystemSocketDescriptor) {
        let listener = try SystemSocketDescriptor.socket(
            domain: .inet,
            type: .stream,
            protocol: .default
        )

        var reuse: Int32 = 1
        _ = listener.unsafe { fd in
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        }

        let bindAddr = try IPv4SocketAddress(address: "127.0.0.1", port: 0)
        try listener.bind(address: bindAddr)
        try listener.listen(backlog: 1)

        // Read back the auto-assigned port.
        var sin = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let port: UInt16 = listener.unsafe { fd in
            withUnsafeMutablePointer(to: &sin) { sinPtr -> UInt16 in
                sinPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    _ = Glibc.getsockname(fd, saPtr, &len)
                }
                return UInt16(bigEndian: sinPtr.pointee.sin_port)
            }
        }

        let client = try SystemSocketDescriptor.socket(
            domain: .inet,
            type: .stream,
            protocol: .default
        )
        let connectAddr = try IPv4SocketAddress(address: "127.0.0.1", port: port)
        try client.connect(address: connectAddr)

        let server = try listener.accept()
        listener.close()

        return (server: server, client: client)
    }

    // MARK: - Tests

    func testSendfileBasic() throws {
        let payload = Data(repeating: 0xAB, count: 4096)
        let (path, fileFD) = try makeTempFile(contents: payload)
        defer {
            Glibc.close(fileFD)
            Glibc.unlink(path)
        }

        let pair = try makeConnectedTCPPair()
        defer {
            pair.server.close()
            pair.client.close()
        }

        let serverFD = pair.server.unsafe { $0 }
        let result = try OpaqueDescriptorRef(fileFD).sendTo(
            OpaqueDescriptorRef(serverFD)
        )

        XCTAssertEqual(result.bytesSent, payload.count)
        XCTAssertTrue(result.complete)

        let received = try pair.client.readExact(payload.count)
        XCTAssertEqual(received, payload)
    }

    func testSendfileOffsetAndCount() throws {
        let payload = Data((0..<256).map { UInt8($0) })
        let (path, fileFD) = try makeTempFile(contents: payload)
        defer {
            Glibc.close(fileFD)
            Glibc.unlink(path)
        }

        let pair = try makeConnectedTCPPair()
        defer {
            pair.server.close()
            pair.client.close()
        }

        let offset: off_t = 64
        let count = 100

        let serverFD = pair.server.unsafe { $0 }
        let result = try OpaqueDescriptorRef(fileFD).sendTo(
            OpaqueDescriptorRef(serverFD),
            offset: offset,
            count: count
        )

        XCTAssertEqual(result.bytesSent, count)
        XCTAssertTrue(result.complete)

        let received = try pair.client.readExact(count)
        let expected = payload.subdata(in: Int(offset)..<(Int(offset) + count))
        XCTAssertEqual(received, expected)
    }

    func testSendfileWithHeadersAndTrailers() throws {
        let body = Data("FILE-BODY".utf8)
        let (path, fileFD) = try makeTempFile(contents: body)
        defer {
            Glibc.close(fileFD)
            Glibc.unlink(path)
        }

        let pair = try makeConnectedTCPPair()
        defer {
            pair.server.close()
            pair.client.close()
        }

        let ht = SendfileHeadersTrailers(header: "HDR:", trailer: ":TRL")
        let serverFD = pair.server.unsafe { $0 }

        let result = try OpaqueDescriptorRef(fileFD).sendTo(
            OpaqueDescriptorRef(serverFD),
            headersTrailers: ht
        )

        let expected = Data("HDR:".utf8) + body + Data(":TRL".utf8)
        XCTAssertEqual(result.bytesSent, expected.count)
        XCTAssertTrue(result.complete)

        let received = try pair.client.readExact(expected.count)
        XCTAssertEqual(received, expected)
    }

    func testSendfileAsync() async throws {
        let payload = Data(repeating: 0x77, count: 8192)
        let (path, fileFD) = try makeTempFile(contents: payload)
        defer {
            Glibc.close(fileFD)
            Glibc.unlink(path)
        }

        let pair = try makeConnectedTCPPair()
        defer {
            pair.server.close()
            pair.client.close()
        }

        let serverFD = pair.server.unsafe { $0 }
        let total = try await OpaqueDescriptorRef(fileFD).sendToAsync(
            OpaqueDescriptorRef(serverFD)
        )
        XCTAssertEqual(total, payload.count)

        let received = try pair.client.readExact(payload.count)
        XCTAssertEqual(received, payload)
    }
}
