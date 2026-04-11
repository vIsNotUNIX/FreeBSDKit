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
    /// Returns (server, client) — both are stream sockets connected to
    /// each other. The intermediate listener fd is always closed, even
    /// on failing paths, by holding it as a raw fd.
    private func makeConnectedTCPPair() throws -> (server: SystemSocketDescriptor, client: SystemSocketDescriptor) {
        // Listener is a raw fd so a throwing test path can clean it up
        // unconditionally via defer. Wrapping it in SystemSocketDescriptor
        // would mean an unconsumed ~Copyable on the failing path.
        let listenerFD = Glibc.socket(AF_INET, SOCK_STREAM, 0)
        guard listenerFD >= 0 else { throw POSIXError(.EIO) }
        var listenerOwned = true
        defer { if listenerOwned { Glibc.close(listenerFD) } }

        var reuse: Int32 = 1
        _ = setsockopt(listenerFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Glibc.bind(listenerFD, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw POSIXError(.EIO) }
        guard Glibc.listen(listenerFD, 1) == 0 else { throw POSIXError(.EIO) }

        // Read back the auto-assigned port.
        var sin = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &sin) { sinPtr in
            sinPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                Glibc.getsockname(listenerFD, saPtr, &len)
            }
        }
        let port = UInt16(bigEndian: sin.sin_port)

        // Now create the client and connect.
        let clientFD = Glibc.socket(AF_INET, SOCK_STREAM, 0)
        guard clientFD >= 0 else { throw POSIXError(.EIO) }
        var clientOwned = true
        defer { if clientOwned { Glibc.close(clientFD) } }

        var connectAddr = sockaddr_in()
        connectAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        connectAddr.sin_family = sa_family_t(AF_INET)
        connectAddr.sin_port = port.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &connectAddr.sin_addr)

        let connectResult = withUnsafePointer(to: &connectAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Glibc.connect(clientFD, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else { throw POSIXError(.EIO) }

        let acceptedFD = Glibc.accept(listenerFD, nil, nil)
        guard acceptedFD >= 0 else { throw POSIXError(.EIO) }

        // Hand off ownership: wrap the accepted+client fds, release the
        // raw-fd handles so the defers don't double-close.
        let server = SystemSocketDescriptor(acceptedFD)
        let client = SystemSocketDescriptor(clientFD)
        clientOwned = false
        Glibc.close(listenerFD)
        listenerOwned = false

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
