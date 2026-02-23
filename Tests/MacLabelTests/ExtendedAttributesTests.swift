/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid path"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid path"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid attribute name"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid attribute name"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid path"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid attribute name"))
            }
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
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid path"))
            }
        }
    }

    func testExtAttrList_InvalidPath_Empty() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.list(
                path: "",
                namespace: .system
            )
        ) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid path"))
            }
        }
    }

    func testExtAttrSetFd_InvalidFd() throws {
        let data = Data("test".utf8)

        XCTAssertThrowsError(
            try ExtendedAttributes.setFd(
                fd: -1,
                namespace: .system,
                name: "test.attr",
                data: data
            )
        ) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid file descriptor"))
            }
        }
    }

    func testExtAttrGetFd_InvalidFd() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.getFd(
                fd: -1,
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid file descriptor"))
            }
        }
    }

    func testExtAttrDeleteFd_InvalidFd() throws {
        XCTAssertThrowsError(
            try ExtendedAttributes.deleteFd(
                fd: -1,
                namespace: .system,
                name: "test.attr"
            )
        ) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid file descriptor"))
            }
        }
    }
}
