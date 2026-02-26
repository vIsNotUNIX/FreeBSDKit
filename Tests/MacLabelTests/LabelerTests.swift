/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
@testable import FreeBSDKit
import Foundation

final class LabelerTests: XCTestCase {

    let testAttributeName = "mac_test.\(UUID().uuidString)"
    var testFiles: [String] = []
    var isRoot: Bool = false

    override func setUp() {
        super.setUp()
        testFiles = []
        isRoot = getuid() == 0
    }

    private func requireRoot() throws {
        guard isRoot else {
            throw XCTSkip("This test requires root privileges to set system namespace extended attributes")
        }
    }

    override func tearDown() {
        // Clean up test files
        for file in testFiles {
            try? FileManager.default.removeItem(atPath: file)

            // Also try to remove extended attributes
            try? ExtendedAttributes.delete(
                path: file,
                namespace: .system,
                name: testAttributeName
            )
        }
        testFiles = []
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func createTestFile(content: String = "test") -> String {
        let tempDir = NSTemporaryDirectory()
        let fileName = "test-file-\(UUID().uuidString).txt"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        try! content.write(toFile: filePath, atomically: true, encoding: .utf8)
        testFiles.append(filePath)

        return filePath
    }

    private func createTestConfiguration(labels: [FileLabel]) -> LabelConfiguration<FileLabel> {
        return LabelConfiguration(
            attributeName: testAttributeName,
            labels: labels
        )
    }

    // MARK: - Path Validation Tests

    func testLabeler_ValidateAllPaths_AllExist() throws {
        let file1 = createTestFile()
        let file2 = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file1, attributes: ["type": "test1"]),
            FileLabel(path: file2, attributes: ["type": "test2"])
        ])

        let labeler = Labeler(configuration: config)

        // Should not throw
        XCTAssertNoThrow(try labeler.validatePaths())
    }

    func testLabeler_ValidateAllPaths_OneMissing() throws {
        let file1 = createTestFile()
        let missingFile = "/tmp/this-file-does-not-exist-\(UUID().uuidString)"

        let config = createTestConfiguration(labels: [
            FileLabel(path: file1, attributes: ["type": "test1"]),
            FileLabel(path: missingFile, attributes: ["type": "test2"])
        ])

        let labeler = Labeler(configuration: config)

        XCTAssertThrowsError(try labeler.validatePaths()) { error in
            XCTAssertTrue(error is LabelError)
            if case .fileNotFound(let path) = error as? LabelError {
                XCTAssertEqual(path, missingFile)
            }
        }
    }

    // MARK: - Apply Labels Tests

    func testLabeler_ApplyLabels_Success() throws {
        try requireRoot()

        let file = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: [
                "type": "test",
                "trust": "low"
            ])
        ])

        var labeler = Labeler(configuration: config)
        labeler.verbose = false

        let results = try labeler.apply()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertEqual(results[0].path, file)
        XCTAssertNil(results[0].error)

        // Verify labels were actually set
        let data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertNotNil(data)
        let string = String(data: data!, encoding: .utf8)
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("trust=low"))
        XCTAssertTrue(string!.contains("type=test"))
    }

    func testLabeler_ApplyLabels_FailsIfPathMissing() throws {
        let file1 = createTestFile()
        let missingFile = "/tmp/missing-\(UUID().uuidString)"

        let config = createTestConfiguration(labels: [
            FileLabel(path: file1, attributes: ["type": "test1"]),
            FileLabel(path: missingFile, attributes: ["type": "test2"])
        ])

        let labeler = Labeler(configuration: config)

        // Should throw because one file is missing
        XCTAssertThrowsError(try labeler.apply()) { error in
            XCTAssertTrue(error is LabelError)
            if case .fileNotFound(let path) = error as? LabelError {
                XCTAssertEqual(path, missingFile)
            }
        }

        // Verify no labels were set on file1 (atomic operation)
        let data = try? ExtendedAttributes.get(
            path: file1,
            namespace: .system,
            name: testAttributeName
        )

        // Should be nil because operation failed before applying
        XCTAssertNil(data)
    }

    func testLabeler_ApplyLabels_OverwriteExisting() throws {
        try requireRoot()

        let file = createTestFile()

        // First, apply initial labels
        let initialConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "initial"])
        ])

        let initialLabeler = Labeler(configuration: initialConfig)
        _ = try initialLabeler.apply()

        // Now apply new labels with overwrite
        let newConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "new", "version": "2"])
        ])

        var newLabeler = Labeler(configuration: newConfig)
        newLabeler.overwriteExisting = true

        let results = try newLabeler.apply()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)

        // Verify new labels were set
        let data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        let string = String(data: data!, encoding: .utf8)
        XCTAssertTrue(string!.contains("type=new"))
        XCTAssertTrue(string!.contains("version=2"))
        XCTAssertFalse(string!.contains("type=initial"))
    }

    func testLabeler_ApplyLabels_NoOverwrite() throws {
        try requireRoot()

        let file = createTestFile()

        // First, apply initial labels
        let initialConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "initial"])
        ])

        let initialLabeler = Labeler(configuration: initialConfig)
        _ = try initialLabeler.apply()

        // Try to apply new labels without overwrite
        let newConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "new"])
        ])

        var newLabeler = Labeler(configuration: newConfig)
        newLabeler.overwriteExisting = false

        let results = try newLabeler.apply()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success) // Success but didn't overwrite

        // Verify old labels are still there
        let data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        let string = String(data: data!, encoding: .utf8)
        XCTAssertTrue(string!.contains("type=initial"))
        XCTAssertFalse(string!.contains("type=new"))
    }

    // MARK: - Remove Labels Tests

    func testLabeler_RemoveLabels_Success() throws {
        try requireRoot()

        let file = createTestFile()

        // First apply labels
        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let labeler = Labeler(configuration: config)
        _ = try labeler.apply()

        // Verify labels exist
        var data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )
        XCTAssertNotNil(data)

        // Remove labels
        let results = try labeler.remove()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)

        // Verify labels are gone
        data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )
        XCTAssertNil(data)
    }

    // MARK: - Verify Labels Tests

    func testLabeler_VerifyLabels_Match() throws {
        try requireRoot()

        let file = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: [
                "type": "test",
                "version": "1"
            ])
        ])

        let labeler = Labeler(configuration: config)

        // Apply labels
        _ = try labeler.apply()

        // Verify labels
        let results = try labeler.verify()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].matches)
        XCTAssertEqual(results[0].path, file)
        XCTAssertEqual(results[0].mismatches.count, 0)
    }

    func testLabeler_VerifyLabels_NoLabelsOnFile() throws {
        try requireRoot()

        let file = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let labeler = Labeler(configuration: config)

        // Don't apply labels, just verify
        let results = try labeler.verify()

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].matches)
        XCTAssertTrue(results[0].mismatches.count > 0)
        XCTAssertTrue(results[0].mismatches[0].contains("No labels found"))
    }

    func testLabeler_VerifyLabels_MissingKey() throws {
        try requireRoot()

        let file = createTestFile()

        // Apply labels with fewer attributes
        let applyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let applyLabeler = Labeler(configuration: applyConfig)
        _ = try applyLabeler.apply()

        // Verify with more attributes expected
        let verifyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: [
                "type": "test",
                "version": "1"
            ])
        ])

        let verifyLabeler = Labeler(configuration: verifyConfig)
        let results = try verifyLabeler.verify()

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].matches)
        XCTAssertTrue(results[0].mismatches.contains { $0.contains("Missing key: 'version'") })
    }

    func testLabeler_VerifyLabels_ExtraKey() throws {
        try requireRoot()

        let file = createTestFile()

        // Apply labels with extra attributes
        let applyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: [
                "type": "test",
                "version": "1"
            ])
        ])

        let applyLabeler = Labeler(configuration: applyConfig)
        _ = try applyLabeler.apply()

        // Verify with fewer attributes expected
        let verifyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let verifyLabeler = Labeler(configuration: verifyConfig)
        let results = try verifyLabeler.verify()

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].matches)
        XCTAssertTrue(results[0].mismatches.contains { $0.contains("Unexpected key: 'version'") })
    }

    func testLabeler_VerifyLabels_WrongValue() throws {
        try requireRoot()

        let file = createTestFile()

        // Apply labels with one value
        let applyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let applyLabeler = Labeler(configuration: applyConfig)
        _ = try applyLabeler.apply()

        // Verify expecting different value
        let verifyConfig = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "production"])
        ])

        let verifyLabeler = Labeler(configuration: verifyConfig)
        let results = try verifyLabeler.verify()

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].matches)
        XCTAssertTrue(results[0].mismatches.contains { $0.contains("expected 'production', got 'test'") })
    }

    // MARK: - Show Labels Tests

    func testLabeler_ShowLabels_WithLabels() throws {
        try requireRoot()

        let file = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: ["type": "test"])
        ])

        let labeler = Labeler(configuration: config)
        _ = try labeler.apply()

        let results = try labeler.show()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, file)
        XCTAssertNotNil(results[0].labels)
        XCTAssertTrue(results[0].labels!.contains("type=test"))
    }

    func testLabeler_ShowLabels_NoLabels() throws {
        try requireRoot()

        let file = createTestFile()

        let config = createTestConfiguration(labels: [
            FileLabel(path: file, attributes: [:])
        ])

        let labeler = Labeler(configuration: config)

        let results = try labeler.show()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, file)
        XCTAssertNil(results[0].labels)
    }
}
