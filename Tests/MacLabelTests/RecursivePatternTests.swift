/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import MacLabel
import Foundation

/// Tests for recursive pattern expansion and duplicate detection.
final class RecursivePatternTests: XCTestCase {

    var testDir: String = ""

    override func setUp() {
        super.setUp()
        // Create a test directory structure
        testDir = NSTemporaryDirectory() + "maclabel-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testDir)
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createFile(_ relativePath: String, content: String = "test") {
        let fullPath = (testDir as NSString).appendingPathComponent(relativePath)
        let dir = (fullPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? content.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }

    private func createSymlink(_ relativePath: String, to target: String) {
        let fullPath = (testDir as NSString).appendingPathComponent(relativePath)
        let dir = (fullPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? FileManager.default.createSymbolicLink(atPath: fullPath, withDestinationPath: target)
    }

    // MARK: - Pattern Detection Tests

    func testIsRecursivePattern_WithWildcard() {
        let label = FileLabel(path: "/usr/local/bin/*", attributes: [:])
        XCTAssertTrue(label.isRecursivePattern)
    }

    func testIsRecursivePattern_WithoutWildcard() {
        let label = FileLabel(path: "/usr/local/bin/app", attributes: [:])
        XCTAssertFalse(label.isRecursivePattern)
    }

    func testIsRecursivePattern_WildcardInMiddle() {
        // Only trailing /* is a pattern
        let label = FileLabel(path: "/usr/*/bin", attributes: [:])
        XCTAssertFalse(label.isRecursivePattern)
    }

    func testDirectoryPath_ExtractsCorrectly() {
        let label = FileLabel(path: "/usr/local/bin/*", attributes: [:])
        XCTAssertEqual(label.directoryPath, "/usr/local/bin")
    }

    func testDirectoryPath_NilForNonPattern() {
        let label = FileLabel(path: "/usr/local/bin/app", attributes: [:])
        XCTAssertNil(label.directoryPath)
    }

    // MARK: - Pattern Expansion Tests

    func testExpandedPaths_EnumeratesAllFiles() throws {
        // Create test structure
        createFile("file1.txt")
        createFile("file2.txt")
        createFile("subdir/file3.txt")
        createFile("subdir/nested/file4.txt")

        let label = FileLabel(path: testDir + "/*", attributes: [:])
        let paths = try label.expandedPaths()

        XCTAssertEqual(paths.count, 4)
        XCTAssertTrue(paths.contains { $0.hasSuffix("file1.txt") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("file2.txt") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("file3.txt") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("file4.txt") })
    }

    func testExpandedPaths_ExcludesDirectories() throws {
        createFile("file.txt")
        try FileManager.default.createDirectory(
            atPath: testDir + "/emptydir",
            withIntermediateDirectories: true
        )

        let label = FileLabel(path: testDir + "/*", attributes: [:])
        let paths = try label.expandedPaths()

        // Should only have the file, not the directory
        XCTAssertEqual(paths.count, 1)
        XCTAssertTrue(paths[0].hasSuffix("file.txt"))
    }

    func testExpandedPaths_IsSorted() throws {
        createFile("zebra.txt")
        createFile("apple.txt")
        createFile("middle.txt")

        let label = FileLabel(path: testDir + "/*", attributes: [:])
        let paths = try label.expandedPaths()

        XCTAssertEqual(paths, paths.sorted())
    }

    func testExpandedPaths_NonPatternReturnsItself() throws {
        createFile("single.txt")
        let path = testDir + "/single.txt"

        let label = FileLabel(path: path, attributes: [:])
        let paths = try label.expandedPaths()

        XCTAssertEqual(paths, [path])
    }

    func testExpandedPaths_FailsForNonExistentDirectory() {
        let label = FileLabel(path: "/nonexistent-\(UUID())/*", attributes: [:])

        XCTAssertThrowsError(try label.expandedPaths()) { error in
            guard case .invalidConfiguration = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
        }
    }

    func testExpandedPaths_FailsIfNotADirectory() throws {
        createFile("file.txt")
        let label = FileLabel(path: testDir + "/file.txt/*", attributes: [:])

        XCTAssertThrowsError(try label.expandedPaths()) { error in
            guard case .invalidConfiguration(let msg) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(msg.contains("not a directory"))
        }
    }

    // MARK: - Expanded Labels Tests

    func testExpandedLabels_PreservesAttributes() throws {
        createFile("file1.txt")
        createFile("file2.txt")

        let attributes = ["type": "test", "trust": "low"]
        let label = FileLabel(path: testDir + "/*", attributes: attributes)
        let expanded = try label.expandedLabels()

        XCTAssertEqual(expanded.count, 2)
        for expandedLabel in expanded {
            XCTAssertEqual(expandedLabel.attributes, attributes)
        }
    }

    // MARK: - Duplicate Detection Tests

    func testDetectDuplicates_NoOverlap() throws {
        createFile("dir1/file1.txt")
        createFile("dir2/file2.txt")

        let config = LabelConfiguration<FileLabel>(
            attributeName: "mac_test",
            labels: [
                FileLabel(path: testDir + "/dir1/*", attributes: ["source": "dir1"]),
                FileLabel(path: testDir + "/dir2/*", attributes: ["source": "dir2"])
            ]
        )

        let labeler = Labeler(configuration: config)
        let duplicates = try labeler.detectDuplicates()

        XCTAssertTrue(duplicates.isEmpty)
    }

    func testDetectDuplicates_PatternAndExplicitOverlap() throws {
        createFile("file1.txt")
        createFile("file2.txt")

        let specificPath = testDir + "/file1.txt"
        let config = LabelConfiguration<FileLabel>(
            attributeName: "mac_test",
            labels: [
                FileLabel(path: testDir + "/*", attributes: ["source": "pattern"]),
                FileLabel(path: specificPath, attributes: ["source": "explicit"])
            ]
        )

        let labeler = Labeler(configuration: config)
        let duplicates = try labeler.detectDuplicates()

        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates[0].path, specificPath)
        XCTAssertEqual(duplicates[0].sources.count, 2)
        XCTAssertEqual(duplicates[0].sources[0], testDir + "/*")
        XCTAssertEqual(duplicates[0].sources[1], specificPath)
    }

    func testDetectDuplicates_MultiplePatternOverlap() throws {
        // Create nested structure where both patterns match
        createFile("shared/file.txt")

        let config = LabelConfiguration<FileLabel>(
            attributeName: "mac_test",
            labels: [
                FileLabel(path: testDir + "/*", attributes: ["source": "root"]),
                FileLabel(path: testDir + "/shared/*", attributes: ["source": "shared"])
            ]
        )

        let labeler = Labeler(configuration: config)
        let duplicates = try labeler.detectDuplicates()

        // The file in shared/ is matched by both patterns
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertTrue(duplicates[0].path.hasSuffix("shared/file.txt"))
    }

    // MARK: - Symlink Detection Tests

    func testSymlinkTarget_ReturnsTargetForSymlink() throws {
        createFile("real.txt", content: "real file")
        createSymlink("link.txt", to: "real.txt")

        let label = FileLabel(path: testDir + "/link.txt", attributes: [:])
        let target = label.symlinkTarget()

        XCTAssertNotNil(target)
        XCTAssertEqual(target, "real.txt")
    }

    func testSymlinkTarget_ReturnsNilForRegularFile() throws {
        createFile("regular.txt")

        let label = FileLabel(path: testDir + "/regular.txt", attributes: [:])
        let target = label.symlinkTarget()

        XCTAssertNil(target)
    }

    func testResolvedPath_FollowsSymlinks() throws {
        createFile("real.txt", content: "real file")
        createSymlink("link.txt", to: "real.txt")

        let label = FileLabel(path: testDir + "/link.txt", attributes: [:])
        let resolved = label.resolvedPath()

        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved!.hasSuffix("real.txt"))
        XCTAssertFalse(resolved!.contains("link"))
    }

    func testResolvedPath_ReturnsCanonicalForRegularFile() throws {
        createFile("regular.txt")

        let label = FileLabel(path: testDir + "/regular.txt", attributes: [:])
        let resolved = label.resolvedPath()

        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved!.hasSuffix("regular.txt"))
    }

    // MARK: - Validation Tests

    func testValidate_PatternWithValidDirectory() throws {
        try FileManager.default.createDirectory(
            atPath: testDir + "/validdir",
            withIntermediateDirectories: true
        )

        let label = FileLabel(path: testDir + "/validdir/*", attributes: [:])
        XCTAssertNoThrow(try label.validate())
    }

    func testValidate_PatternWithNonExistentDirectory() {
        let label = FileLabel(path: "/nonexistent-\(UUID())/*", attributes: [:])

        XCTAssertThrowsError(try label.validate()) { error in
            guard case .fileNotFound = error as? LabelError else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }

    func testValidate_PatternWithFileNotDirectory() throws {
        createFile("file.txt")

        let label = FileLabel(path: testDir + "/file.txt/*", attributes: [:])

        XCTAssertThrowsError(try label.validate()) { error in
            guard case .invalidConfiguration(let msg) = error as? LabelError else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(msg.contains("not a directory"))
        }
    }
}
