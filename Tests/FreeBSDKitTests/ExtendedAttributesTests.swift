/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit
import Foundation

final class ExtendedAttributesTests: XCTestCase {

    // MARK: - Input Validation Tests

    func testExtAttrSet_InvalidPath_Empty() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.set(
                path: "",
                namespace: .system,
                name: "test.attr",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidPath = error as? ExtAttrError {}
        }
    }

    func testExtAttrSet_InvalidPath_NullByte() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.set(
                path: "/bin/sh\0malicious",
                namespace: .system,
                name: "test.attr",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidPath = error as? ExtAttrError {}
        }
    }

    func testExtAttrSet_InvalidName_Empty() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.set(
                path: "/bin/sh",
                namespace: .system,
                name: "",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidAttributeName = error as? ExtAttrError {}
        }
    }

    func testExtAttrSet_InvalidName_NullByte() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.set(
                path: "/bin/sh",
                namespace: .system,
                name: "test\0attr",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidAttributeName = error as? ExtAttrError {}
        }
    }

    func testExtAttrGet_InvalidPath_Empty() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.get(
                path: "",
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidPath = error as? ExtAttrError {}
        }
    }

    func testExtAttrGet_InvalidName_Empty() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.get(
                path: "/bin/sh",
                namespace: .system,
                name: ""
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidAttributeName = error as? ExtAttrError {}
        }
    }

    func testExtAttrDelete_InvalidPath_Empty() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.delete(
                path: "",
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidPath = error as? ExtAttrError {}
        }
    }

    func testExtAttrList_InvalidPath_Empty() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.list(
                path: "",
                namespace: .system
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidPath = error as? ExtAttrError {}
        }
    }

    func testExtAttrSetFd_InvalidFd() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.set(
                fd: -1,
                namespace: .system,
                name: "test.attr",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidFileDescriptor = error as? ExtAttrError {}
        }
    }

    func testExtAttrGetFd_InvalidFd() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.get(
                fd: -1,
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidFileDescriptor = error as? ExtAttrError {}
        }
    }

    func testExtAttrDeleteFd_InvalidFd() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.delete(
                fd: -1,
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is ExtAttrError)
            if case .invalidFileDescriptor = error as? ExtAttrError {}
        }
    }
}
