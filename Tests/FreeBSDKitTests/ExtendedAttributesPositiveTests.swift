/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit
import Foundation
import Glibc

/// Positive tests for ExtendedAttributes that actually set, get, and delete attributes.
///
/// These tests require root privileges to set system namespace extended attributes.
/// They will be skipped when run as a regular user.
final class ExtendedAttributesPositiveTests: XCTestCase {

    let testAttributeName = "mac.test.\(UUID().uuidString)"
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
        // Clean up test files and attributes
        for file in testFiles {
            // Try to remove extended attribute first
            try? ExtendedAttributes.delete(
                path: file,
                namespace: .system,
                name: testAttributeName
            )
            // Then remove the file
            try? FileManager.default.removeItem(atPath: file)
        }
        testFiles = []
        super.tearDown()
    }

    private func createTestFile(content: String = "test") -> String {
        let tempDir = NSTemporaryDirectory()
        let fileName = "test-file-\(UUID().uuidString).txt"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        try! content.write(toFile: filePath, atomically: true, encoding: .utf8)
        testFiles.append(filePath)

        return filePath
    }

    // MARK: - Set/Get/Delete Tests

    func testExtAttr_SetAndGet_SystemNamespace() throws {
        try requireRoot()

        let file = createTestFile()
        let testData = Data("test=value\n".utf8)

        // Set attribute
        XCTAssertNoThrow(try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: testData
        ))

        // Get attribute
        let retrievedData = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData, testData)
    }

    func testExtAttr_SetAndGet_UserNamespace() throws {
        let file = createTestFile()
        let testData = Data("user=data\n".utf8)

        // Set attribute in user namespace (doesn't require root)
        XCTAssertNoThrow(try ExtendedAttributes.set(
            path: file,
            namespace: .user,
            name: testAttributeName,
            data: testData
        ))

        // Get attribute
        let retrievedData = try ExtendedAttributes.get(
            path: file,
            namespace: .user,
            name: testAttributeName
        )

        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData, testData)

        // Clean up user namespace attribute
        try? ExtendedAttributes.delete(
            path: file,
            namespace: .user,
            name: testAttributeName
        )
    }

    func testExtAttr_GetNonExistent_ReturnsNil() throws {
        // Use user namespace since it doesn't require root
        let file = createTestFile()

        let data = try ExtendedAttributes.get(
            path: file,
            namespace: .user,
            name: "nonexistent.attribute.\(UUID().uuidString)"
        )

        XCTAssertNil(data)
    }

    func testExtAttr_SetOverwrite() throws {
        try requireRoot()

        let file = createTestFile()
        let firstData = Data("first=value\n".utf8)
        let secondData = Data("second=value\n".utf8)

        // Set first value
        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: firstData
        )

        // Overwrite with second value
        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: secondData
        )

        // Should get second value
        let retrievedData = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertEqual(retrievedData, secondData)
    }

    func testExtAttr_Delete() throws {
        try requireRoot()

        let file = createTestFile()
        let testData = Data("delete=me\n".utf8)

        // Set attribute
        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: testData
        )

        // Verify it exists
        var data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )
        XCTAssertNotNil(data)

        // Delete it
        try ExtendedAttributes.delete(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        // Verify it's gone
        data = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )
        XCTAssertNil(data)
    }

    func testExtAttr_EmptyValue() throws {
        try requireRoot()

        let file = createTestFile()
        let emptyData = Data()

        // Set empty attribute
        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: emptyData
        )

        // Get it back
        let retrievedData = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?.count, 0)
    }

    func testExtAttr_LargeValue() throws {
        try requireRoot()

        let file = createTestFile()
        // Create a large value (e.g., 4KB)
        let largeData = Data(repeating: UInt8(ascii: "X"), count: 4096)

        // Set large attribute
        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: testAttributeName,
            data: largeData
        )

        // Get it back
        let retrievedData = try ExtendedAttributes.get(
            path: file,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData, largeData)
    }

    // MARK: - File Descriptor Tests

    func testExtAttr_SetAndGetFd() throws {
        try requireRoot()

        let file = createTestFile()
        let testData = Data("fd=test\n".utf8)

        // Open file
        let fd = open(file, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open file")
        defer { close(fd) }

        // Set attribute using fd
        try ExtendedAttributes.set(
            fd: fd,
            namespace: .system,
            name: testAttributeName,
            data: testData
        )

        // Get attribute using fd
        let retrievedData = try ExtendedAttributes.get(
            fd: fd,
            namespace: .system,
            name: testAttributeName
        )

        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData, testData)
    }

    func testExtAttr_DeleteFd() throws {
        try requireRoot()

        let file = createTestFile()
        let testData = Data("delete=me\n".utf8)

        // Open file
        let fd = open(file, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open file")
        defer { close(fd) }

        // Set attribute
        try ExtendedAttributes.set(
            fd: fd,
            namespace: .system,
            name: testAttributeName,
            data: testData
        )

        // Delete using fd
        try ExtendedAttributes.delete(
            fd: fd,
            namespace: .system,
            name: testAttributeName
        )

        // Verify it's gone
        let data = try ExtendedAttributes.get(
            fd: fd,
            namespace: .system,
            name: testAttributeName
        )
        XCTAssertNil(data)
    }

    // MARK: - List Tests

    func testExtAttr_List() throws {
        try requireRoot()

        let file = createTestFile()

        // Set multiple attributes
        let attr1 = "test.attr1.\(UUID().uuidString)"
        let attr2 = "test.attr2.\(UUID().uuidString)"

        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: attr1,
            data: Data("value1".utf8)
        )

        try ExtendedAttributes.set(
            path: file,
            namespace: .system,
            name: attr2,
            data: Data("value2".utf8)
        )

        defer {
            try? ExtendedAttributes.delete(path: file, namespace: .system, name: attr1)
            try? ExtendedAttributes.delete(path: file, namespace: .system, name: attr2)
        }

        // List attributes
        let attributes = try ExtendedAttributes.list(
            path: file,
            namespace: .system
        )

        // Should contain both our attributes
        XCTAssertTrue(attributes.contains(attr1))
        XCTAssertTrue(attributes.contains(attr2))
    }

    func testExtAttr_ListEmpty() throws {
        let file = createTestFile()

        // List attributes in user namespace (doesn't require root)
        let attributes = try ExtendedAttributes.list(
            path: file,
            namespace: .user
        )

        // May be empty or contain user attributes, but shouldn't crash
        XCTAssertNotNil(attributes)
    }
}
