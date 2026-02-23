/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
import Foundation

/// Tests for bad input validation and error handling.
///
/// These tests ensure the tool properly rejects invalid input at various stages:
/// - Configuration file format
/// - Attribute name validation
/// - Attribute key/value validation
/// - File path validation
final class BadInputTests: XCTestCase {

    // MARK: - Configuration File Format Tests

    func testEmptyConfigurationFile() throws {
        // Create empty file
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-config.json")
        try Data().write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Should fail - empty file
        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path)) { error in
            XCTAssertTrue(error is LabelError, "Expected LabelError for empty file")
        }
    }

    func testInvalidJSON() throws {
        let invalidJSON = """
        {
          "attributeName": "mac.labels",
          "labels": [
            {
              "path": "/bin/sh"
              # Missing comma and attributes field
            }
          ]
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid.json")
        try invalidJSON.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path))
    }

    func testMissingRequiredAttributeName() throws {
        let json = """
        {
          "labels": [
            {
              "path": "/bin/sh",
              "attributes": {"type": "shell"}
            }
          ]
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-attr-name.json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path))
    }

    func testTooLargeConfigurationFile() throws {
        // Create a file > 10MB
        let largeData = Data(repeating: 0x41, count: 10_485_761)  // 10MB + 1 byte

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("large-config.json")
        try largeData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path)) { error in
            guard case .invalidConfiguration(let message) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("exceeds maximum size"))
        }
    }

    // MARK: - Attribute Name Validation Tests

    func testEmptyAttributeName() throws {
        let json = """
        {
          "attributeName": "",
          "labels": []
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-attr.json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path)) { error in
            guard case .invalidConfiguration(let message) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("cannot be empty"))
        }
    }

    func testAttributeNameWithForbiddenCharacters() throws {
        let forbiddenNames = [
            "mac/labels",      // Contains /
            "mac labels",      // Contains space
            "mac.labels\n",    // Contains newline
            "mac.labels!",     // Contains special char
            "mac@labels",      // Contains @
        ]

        for forbiddenName in forbiddenNames {
            // Use JSONEncoder to create properly escaped JSON
            let configDict: [String: Any] = [
                "attributeName": forbiddenName,
                "labels": []
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: configDict)

            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("forbidden-\(UUID()).json")
            try jsonData.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            XCTAssertThrowsError(
                try TestHelpers.loadConfiguration(from: tempFile.path),
                "Attribute name '\(forbiddenName)' should be rejected"
            ) { error in
                guard case .invalidConfiguration = error as? LabelError else {
                    XCTFail("Expected invalidConfiguration error for '\(forbiddenName)'")
                    return
                }
            }
        }
    }

    func testAttributeNameTooLong() throws {
        let longName = String(repeating: "a", count: 256)  // > 255 bytes

        let json = """
        {
          "attributeName": "\(longName)",
          "labels": []
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("long-attr.json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path)) { error in
            guard case .invalidConfiguration(let message) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("exceeds maximum length"))
        }
    }

    // MARK: - Attribute Key Validation Tests

    func testEmptyAttributeKey() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["": "value"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute(let message) = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
            XCTAssertTrue(message.contains("cannot be empty"))
        }
    }

    func testAttributeKeyWithEquals() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["bad=key": "value"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute(let message) = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
            XCTAssertTrue(message.contains("contains forbidden character"))
            XCTAssertTrue(message.contains("="))
        }
    }

    func testAttributeKeyWithNewline() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["bad\nkey": "value"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute(let message) = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
            XCTAssertTrue(message.contains("forbidden character"))
        }
    }

    func testAttributeKeyWithNull() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["bad\0key": "value"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
        }
    }

    // MARK: - Attribute Value Validation Tests

    func testAttributeValueWithNewline() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["key": "bad\nvalue"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute(let message) = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
            XCTAssertTrue(message.contains("forbidden character"))
        }
    }

    func testAttributeValueWithNull() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["key": "bad\0value"]
        )

        XCTAssertThrowsError(try label.validateAttributes()) { error in
            guard case .invalidAttribute = error as? LabelError else {
                XCTFail("Expected invalidAttribute error")
                return
            }
        }
    }

    func testAttributeValueWithEquals() throws {
        // This should be VALID - values can contain '='
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["url": "http://example.com?key=value"]
        )

        XCTAssertNoThrow(try label.validateAttributes())
    }

    func testEmptyAttributeValue() throws {
        // This should be VALID - empty values are allowed
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["key": ""]
        )

        XCTAssertNoThrow(try label.validateAttributes())
    }

    // MARK: - File Path Validation Tests

    func testEmptyFilePath() throws {
        let label = FileLabel(
            path: "",
            attributes: ["type": "test"]
        )

        XCTAssertThrowsError(try label.validate()) { error in
            guard case .invalidConfiguration(let message) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("cannot be empty"))
        }
    }

    func testFilePathWithNull() throws {
        let label = FileLabel(
            path: "/tmp/test\0file",
            attributes: ["type": "test"]
        )

        XCTAssertThrowsError(try label.validate()) { error in
            guard case .invalidConfiguration(let message) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("null bytes"))
        }
    }

    func testNonExistentFile() throws {
        let label = FileLabel(
            path: "/nonexistent/path/\(UUID())/file",
            attributes: ["type": "test"]
        )

        XCTAssertThrowsError(try label.validate()) { error in
            guard case .fileNotFound = error as? LabelError else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }

    // MARK: - Encoding Tests

    func testEncodingValidatesAttributes() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: ["bad=key": "value"]
        )

        // encodeAttributes() should also validate
        XCTAssertThrowsError(try label.encodeAttributes()) { error in
            guard case .invalidAttribute = error as? LabelError else {
                XCTFail("Expected invalidAttribute error during encoding")
                return
            }
        }
    }

    func testEncodingProducesSortedOutput() throws {
        let label = FileLabel(
            path: "/tmp/test",
            attributes: [
                "zzz": "last",
                "aaa": "first",
                "mmm": "middle"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, "aaa=first\nmmm=middle\nzzz=last\n")
    }

    // MARK: - Configuration Loading Integration Tests

    func testConfigurationRejectsInvalidAttributes() throws {
        let json = """
        {
          "attributeName": "mac.labels",
          "labels": [
            {
              "path": "/tmp/test",
              "attributes": {
                "bad=key": "value"
              }
            }
          ]
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-key.json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Should fail during validateAttributes() call in load()
        XCTAssertThrowsError(try TestHelpers.loadConfiguration(from: tempFile.path))
    }

    func testConfigurationRejectsNonExistentFiles() throws {
        let json = """
        {
          "attributeName": "mac.labels",
          "labels": [
            {
              "path": "/nonexistent/\(UUID())",
              "attributes": {"type": "test"}
            }
          ]
        }
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-file.json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let config = try TestHelpers.loadConfiguration(from: tempFile.path)
        let labeler = Labeler(configuration: config)

        // Should fail during validateAll()
        XCTAssertThrowsError(try labeler.validateAll()) { error in
            guard case .fileNotFound = error as? LabelError else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }
}
