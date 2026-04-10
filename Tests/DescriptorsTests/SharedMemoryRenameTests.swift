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

// MARK: - Test Descriptor Type

/// Minimal SharedMemoryDescriptor conformance for tests.
struct TestSharedMemoryDescriptor: SharedMemoryDescriptor {
    typealias RAWBSD = Int32
    private let fd: Int32

    init(_ fd: Int32) { self.fd = fd }
    consuming func close() { Glibc.close(fd) }
    consuming func take() -> Int32 { fd }
    func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

final class SharedMemoryRenameTests: XCTestCase {

    private func uniqueName(_ tag: String) -> String {
        "/freebsdkit-\(tag)-\(getpid())-\(arc4random())"
    }

    /// Write a 32-bit cookie into a shm object so we can verify identity
    /// after renaming.
    private func writeCookie(_ desc: borrowing TestSharedMemoryDescriptor, value: UInt32) throws {
        try desc.setSize(MemoryLayout<UInt32>.size)
        let region = try desc.map(
            size: MemoryLayout<UInt32>.size,
            protection: [.read, .write],
            flags: .shared
        )
        let ptr = UnsafeMutableRawPointer(mutating: region.base)
            .assumingMemoryBound(to: UInt32.self)
        ptr.pointee = value
        try region.unmap()
    }

    private func readCookie(_ desc: borrowing TestSharedMemoryDescriptor) throws -> UInt32 {
        let region = try desc.map(
            size: MemoryLayout<UInt32>.size,
            protection: .read,
            flags: .shared
        )
        let ptr = UnsafeRawPointer(region.base).assumingMemoryBound(to: UInt32.self)
        let value = ptr.pointee
        try region.unmap()
        return value
    }

    func testRenameMovesShmObject() throws {
        let from = uniqueName("rename-src")
        let to = uniqueName("rename-dst")
        defer {
            _ = try? TestSharedMemoryDescriptor.unlink(name: from)
            _ = try? TestSharedMemoryDescriptor.unlink(name: to)
        }

        let original: TestSharedMemoryDescriptor = try .open(
            name: from,
            accessMode: .readWrite,
            flags: [.create, .exclusive],
            mode: 0o600
        )
        try writeCookie(original, value: 0xC0FFEE)
        original.close()

        try TestSharedMemoryDescriptor.rename(from: from, to: to)

        // Old name should no longer exist.
        XCTAssertThrowsError(
            try TestSharedMemoryDescriptor.open(
                name: from,
                accessMode: .readOnly,
                flags: [],
                mode: 0
            )
        )

        // New name should hold the original cookie.
        let renamed: TestSharedMemoryDescriptor = try .open(
            name: to,
            accessMode: .readOnly,
            flags: [],
            mode: 0
        )
        defer { renamed.close() }
        XCTAssertEqual(try readCookie(renamed), 0xC0FFEE)
    }

    func testRenameNoReplaceFailsWhenDestinationExists() throws {
        let from = uniqueName("rename-nr-src")
        let to = uniqueName("rename-nr-dst")
        defer {
            _ = try? TestSharedMemoryDescriptor.unlink(name: from)
            _ = try? TestSharedMemoryDescriptor.unlink(name: to)
        }

        let src: TestSharedMemoryDescriptor = try .open(
            name: from, accessMode: .readWrite, flags: [.create, .exclusive], mode: 0o600
        )
        src.close()
        let dst: TestSharedMemoryDescriptor = try .open(
            name: to, accessMode: .readWrite, flags: [.create, .exclusive], mode: 0o600
        )
        dst.close()

        XCTAssertThrowsError(
            try TestSharedMemoryDescriptor.rename(from: from, to: to, flags: .noReplace)
        ) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .EEXIST)
        }
    }

    func testRenameExchangeSwapsTwoObjects() throws {
        let a = uniqueName("rename-xch-a")
        let b = uniqueName("rename-xch-b")
        defer {
            _ = try? TestSharedMemoryDescriptor.unlink(name: a)
            _ = try? TestSharedMemoryDescriptor.unlink(name: b)
        }

        let aDesc: TestSharedMemoryDescriptor = try .open(
            name: a, accessMode: .readWrite, flags: [.create, .exclusive], mode: 0o600
        )
        try writeCookie(aDesc, value: 0xAAAA)
        aDesc.close()

        let bDesc: TestSharedMemoryDescriptor = try .open(
            name: b, accessMode: .readWrite, flags: [.create, .exclusive], mode: 0o600
        )
        try writeCookie(bDesc, value: 0xBBBB)
        bDesc.close()

        try TestSharedMemoryDescriptor.rename(from: a, to: b, flags: .exchange)

        // After exchange, name `a` holds B's cookie and vice versa.
        let openedA: TestSharedMemoryDescriptor = try .open(
            name: a, accessMode: .readOnly, flags: [], mode: 0
        )
        defer { openedA.close() }
        let openedB: TestSharedMemoryDescriptor = try .open(
            name: b, accessMode: .readOnly, flags: [], mode: 0
        )
        defer { openedB.close() }

        XCTAssertEqual(try readCookie(openedA), 0xBBBB)
        XCTAssertEqual(try readCookie(openedB), 0xAAAA)
    }
}
