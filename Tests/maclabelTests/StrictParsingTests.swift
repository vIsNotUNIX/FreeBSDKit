/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import maclabel
import Foundation

final class StrictParsingTests: XCTestCase {

    // MARK: - Encoding Tests

    func testEncoding_ValidAttributesWithEqualsInValue() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "formula": "a=b+c",
                "type": "test"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        // Should be sorted alphabetically
        XCTAssertTrue(string!.contains("formula=a=b+c\n"))
        XCTAssertTrue(string!.contains("type=test\n"))
    }

    func testEncoding_EmptyValue() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key": ""
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertEqual(string, "key=\n")
    }

    func testEncoding_NullByteInKey() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key\0test": "value"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("forbidden character"))
            }
        }
    }

    func testEncoding_NullByteInValue() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key": "value\0test"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("forbidden character"))
            }
        }
    }

    // MARK: - Attribute Name Validation Tests

    func testAttributeNameValidation_LeadingWhitespace() throws {
        let json = """
        {
            "attributeName": " mac.labels",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try LabelConfiguration.load(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("whitespace"))
            }
        }
    }

    func testAttributeNameValidation_TrailingWhitespace() throws {
        let json = """
        {
            "attributeName": "mac.labels ",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try LabelConfiguration.load(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("whitespace"))
            }
        }
    }

    func testAttributeNameValidation_InvalidCharacters() throws {
        let json = """
        {
            "attributeName": "mac@labels",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try LabelConfiguration.load(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("outside safe set"))
            }
        }
    }

    func testAttributeNameValidation_ValidNames() throws {
        let validNames = [
            "mac.labels",
            "mac.network",
            "policy-name",
            "policy_name",
            "Policy123",
            "a.b.c.d"
        ]

        for name in validNames {
            let json = """
            {
                "attributeName": "\(name)",
                "labels": []
            }
            """

            let tempFile = createTempFile(content: json)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }

            let config = try LabelConfiguration.load(from: tempFile)
            XCTAssertEqual(config.attributeName, name)
        }
    }

    // MARK: - Error Message Tests

    func testErrorMessages_IncludeStrerror() throws {
        // Create an error with a known errno
        let error = LabelError.extAttrGetFailed(path: "/test/path", errno: ENOENT)
        let description = error.localizedDescription

        // Should include both numeric errno and string description
        XCTAssertTrue(description.contains("errno="))
        XCTAssertTrue(description.contains("No such file or directory") || description.contains("ENOENT"))
    }

    // MARK: - Helper Methods

    private func createTempFile(content: String) -> String {
        let tempDir = NSTemporaryDirectory()
        let fileName = "test-\(UUID().uuidString).json"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        try! content.write(toFile: filePath, atomically: true, encoding: .utf8)

        return filePath
    }
}
