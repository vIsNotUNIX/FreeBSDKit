/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
import Foundation

final class EdgeCaseTests: XCTestCase {

    // MARK: - Configuration File Size Validation

    func testConfiguration_RejectsOversizedFile() throws {
        // Create a large JSON string (over 10MB)
        let largeArray = Array(repeating: """
            {
                "path": "/bin/sh",
                "attributes": {
                    "key": "value with lots of padding to make file large"
                }
            }
            """, count: 100000)

        let json = """
        {
            "attributeName": "mac.test",
            "labels": [\(largeArray.joined(separator: ","))]
        }
        """

        let tempFile = createTempFile(content: json)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        XCTAssertThrowsError(try LabelConfiguration<FileLabel>.load(from: tempFile)) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("exceeds maximum size"))
            }
        }
    }

    func testConfiguration_EmptyPathValidation() throws {
        XCTAssertThrowsError(try LabelConfiguration<FileLabel>.load(from: "")) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid configuration file path"))
            }
        }
    }

    func testConfiguration_NullByteInPath() throws {
        XCTAssertThrowsError(try LabelConfiguration<FileLabel>.load(from: "/tmp/test\0evil.json")) { error in
            XCTAssertTrue(error is LabelError)
            if case .invalidConfiguration(let message) = error as? LabelError {
                XCTAssertTrue(message.contains("Invalid configuration file path"))
            }
        }
    }

    // MARK: - Empty Value Tests

    func testFileLabel_EmptyValueEncoding() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "key_with_empty_value": "",
                "normal_key": "normal_value"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("key_with_empty_value=\n"))
        XCTAssertTrue(string!.contains("normal_key=normal_value\n"))
    }

    // MARK: - Value with Equals Sign Tests

    func testFileLabel_ValueWithMultipleEquals() throws {
        let label = FileLabel(
            path: "/bin/sh",
            attributes: [
                "formula": "a=b+c=d",
                "equation": "x=y=z"
            ]
        )

        let data = try label.encodeAttributes()
        let string = String(data: data, encoding: .utf8)

        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("formula=a=b+c=d\n"))
        XCTAssertTrue(string!.contains("equation=x=y=z\n"))
    }

    // MARK: - JSON Round-Trip Tests

    func testConfiguration_LoadEdgeCasesExample() throws {
        let config = try LabelConfiguration<FileLabel>.load(from: "../../Examples/maclabel/edge-cases.json")

        XCTAssertEqual(config.attributeName, "mac.test")
        XCTAssertEqual(config.labels.count, 3)

        // Find the label with empty value
        if let catLabel = config.labels.first(where: { $0.path == "/bin/cat" }) {
            XCTAssertEqual(catLabel.attributes["empty_value"], "")
            XCTAssertEqual(catLabel.attributes["has_equals"], "key=value")
            XCTAssertEqual(catLabel.attributes["normal"], "test")
        } else {
            XCTFail("Could not find /bin/cat label")
        }

        // Find the label with formulas
        if let wcLabel = config.labels.first(where: { $0.path == "/usr/bin/wc" }) {
            XCTAssertEqual(wcLabel.attributes["formula"], "a=b+c")
            XCTAssertEqual(wcLabel.attributes["equation"], "x=y*2")
        } else {
            XCTFail("Could not find /usr/bin/wc label")
        }
    }

    func testConfiguration_LoadSingleFileExample() throws {
        let config = try LabelConfiguration<FileLabel>.load(from: "../../Examples/maclabel/single-file.json")

        XCTAssertEqual(config.attributeName, "mac.single")
        XCTAssertEqual(config.labels.count, 1)
        XCTAssertEqual(config.labels[0].path, "/bin/echo")
        XCTAssertEqual(config.labels[0].attributes["trust"], "system")
        XCTAssertEqual(config.labels[0].attributes["readonly"], "true")
    }

    func testConfiguration_LoadComprehensiveExample() throws {
        let config = try LabelConfiguration<FileLabel>.load(from: "../../Examples/maclabel/comprehensive.json")

        XCTAssertEqual(config.attributeName, "mac.comprehensive")
        XCTAssertEqual(config.labels.count, 4)

        // Verify each label has comprehensive attributes
        for label in config.labels {
            XCTAssertTrue(label.attributes.count >= 4, "Label for \(label.path) should have at least 4 attributes")
            XCTAssertNotNil(label.attributes["type"])
            XCTAssertNotNil(label.attributes["trust_level"])
        }
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
