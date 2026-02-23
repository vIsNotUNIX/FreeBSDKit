/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
import Foundation

final class LabelConfigurationTests: XCTestCase {

    // MARK: - Attribute Name Validation

    func testAttributeNameValidation_Empty() throws {
        let json = """
        {
            "attributeName": "",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("cannot be empty"))
            }
        }
    }

    func testAttributeNameValidation_WithSlash() throws {
        let json = """
        {
            "attributeName": "mac/labels",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("invalid characters"))
            }
        }
    }

    func testAttributeNameValidation_WithNewline() throws {
        let json = """
        {
            "attributeName": "mac\\nlabels",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("invalid characters"))
            }
        }
    }

    func testAttributeNameValidation_TooLong() throws {
        let longName = String(repeating: "a", count: 256)
        let json = """
        {
            "attributeName": "\(longName)",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("maximum length"))
            }
        }
    }

    func testAttributeNameValidation_Valid() throws {
        let json = """
        {
            "attributeName": "mac.labels",
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let config = try TestHelpers.loadConfiguration(from: tempFile)
        XCTAssertEqual(config.attributeName, "mac.labels")
        XCTAssertEqual(config.labels.count, 0)
    }

    // MARK: - File Label Tests

    func testFileLabel_EncodeAttributes_Valid() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "type": "shell",
                "trust": "system"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        // Attributes should be sorted alphabetically
        XCTAssertTrue(string!.contains("trust=system\n"))
        XCTAssertTrue(string!.contains("type=shell\n"))
    }

    func testFileLabel_EncodeAttributes_EmptyKey() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "": "value"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("cannot be empty"))
            }
        }
    }

    func testFileLabel_EncodeAttributes_KeyWithEquals() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key=invalid": "value"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("forbidden character"))
            }
        }
    }

    func testFileLabel_EncodeAttributes_KeyWithNewline() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key\ntest": "value"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("forbidden character"))
            }
        }
    }

    func testFileLabel_EncodeAttributes_ValueWithNewline() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key": "value\ntest"
            ]
        )

        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidAttribute(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("forbidden character"))
            }
        }
    }

    func testFileLabel_EncodeAttributes_ValueWithEquals() throws {
        // Values CAN contain equals signs
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "formula": "a=b+c"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertEqual(string, "formula=a=b+c\n")
    }

    func testFileLabel_ValidatePath_Empty() throws {
        let label = FileLabel(
            path: "",
            attributes: [:]
        )

        XCTAssertThrowsError(try label.validate()) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("cannot be empty"))
            }
        }
    }

    func testFileLabel_ValidatePath_FileNotFound() throws {
        let label = FileLabel(
            path: "/this/file/does/not/exist",
            attributes: [:]
        )

        XCTAssertThrowsError(try label.validate()) { error in
            XCTAssertTrue(error is LabelError)
            if case .fileNotFound(let path) = error as? LabelError {
                XCTAssertEqual(path, "/this/file/does/not/exist")
            }
        }
    }

    func testFileLabel_ValidatePath_Valid() throws {
        // Use a file that should exist on FreeBSD
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [:]
        )

        XCTAssertNoThrow(try label.validate())
    }

    // MARK: - Configuration Loading

    func testLabelConfiguration_LoadValid() throws {
        let json = """
        {
            "attributeName": "mac.test",
            "labels": [
                {
                    "path": "/bin/sh",
                    "attributes": {
                        "type": "shell",
                        "trust": "system"
                    }
                }
            ]
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let config = try TestHelpers.loadConfiguration(from: tempFile)
        XCTAssertEqual(config.attributeName, "mac.test")
        XCTAssertEqual(config.labels.count, 1)
        XCTAssertEqual(config.labels[0].path, "/bin/sh")
        XCTAssertEqual(config.labels[0].attributes["type"], "shell")
        XCTAssertEqual(config.labels[0].attributes["trust"], "system")
    }

    func testLabelConfiguration_LoadInvalidJSON() throws {
        let json = "{ invalid json }"

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile))
    }

    func testLabelConfiguration_LoadMissingAttributeName() throws {
        let json = """
        {
            "labels": []
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile))
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
