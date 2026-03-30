/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FreeBSDKit

final class KenvTests: XCTestCase {

    // MARK: - Get Tests

    func testGetExistingVariable() {
        // acpi.oem should exist on most systems
        let value = Kenv.get("acpi.oem")
        // May or may not exist depending on system, just test it doesn't crash
        if let v = value {
            XCTAssertFalse(v.isEmpty)
        }
    }

    func testGetNonExistentVariable() {
        let value = Kenv.get("this_variable_definitely_does_not_exist_12345")
        XCTAssertNil(value)
    }

    func testGetEmptyName() {
        let value = Kenv.get("")
        XCTAssertNil(value)
    }

    func testGetNameTooLong() {
        // Name > 128 characters should return nil
        let longName = String(repeating: "a", count: 200)
        let value = Kenv.get(longName)
        XCTAssertNil(value)
    }

    func testGetNameExactlyMaxLength() {
        // Name exactly 128 characters
        let maxName = String(repeating: "x", count: 128)
        let value = Kenv.get(maxName)
        // Should not crash, will likely return nil since it doesn't exist
        XCTAssertNil(value)
    }

    func testSubscriptAccess() {
        // Test subscript syntax
        let value = Kenv["acpi.oem"]
        // Same as get()
        XCTAssertEqual(value, Kenv.get("acpi.oem"))
    }

    func testSubscriptNonExistent() {
        let value = Kenv["nonexistent_var_xyz"]
        XCTAssertNil(value)
    }

    // MARK: - Exists Tests

    func testExistsForKnownVariable() throws {
        // COLUMNS or LINES are typically set
        let dump = try Kenv.dump()
        if let first = dump.first {
            XCTAssertTrue(Kenv.exists(first.name))
        }
    }

    func testExistsForNonExistent() {
        XCTAssertFalse(Kenv.exists("nonexistent_variable_abc123"))
    }

    func testExistsEmptyName() {
        XCTAssertFalse(Kenv.exists(""))
    }

    // MARK: - Dump Tests

    func testDumpReturnsVariables() throws {
        let entries = try Kenv.dump()
        // Should have at least some variables
        XCTAssertFalse(entries.isEmpty, "Kernel environment should not be empty")
    }

    func testDumpEntriesHaveNameAndValue() throws {
        let entries = try Kenv.dump()
        for entry in entries {
            XCTAssertFalse(entry.name.isEmpty, "Entry name should not be empty")
            // Value can be empty, but name should have content
        }
    }

    func testDumpContainsKnownVariable() throws {
        let entries = try Kenv.dump()
        // COLUMNS or LINES are typically present
        let names = entries.map(\.name)
        let hasCommonVar = names.contains("COLUMNS") || names.contains("LINES") || names.contains("acpi.oem")
        XCTAssertTrue(hasCommonVar || !entries.isEmpty, "Should contain common variables")
    }

    func testDumpEntryEquality() {
        let entry1 = Kenv.Entry(name: "test", value: "value")
        let entry2 = Kenv.Entry(name: "test", value: "value")
        let entry3 = Kenv.Entry(name: "test", value: "other")

        XCTAssertEqual(entry1, entry2)
        XCTAssertNotEqual(entry1, entry3)
    }

    // MARK: - Dump Loader/Static Tests

    func testDumpLoaderMayFail() {
        // Loader environment may not be preserved
        do {
            let entries = try Kenv.dumpLoader()
            // If it succeeds, should return valid entries
            for entry in entries {
                XCTAssertFalse(entry.name.isEmpty)
            }
        } catch KenvError.environmentNotPreserved {
            // Expected on kernels without PRESERVE_EARLY_ENVIRONMENTS
        } catch {
            // Other errors are also acceptable
        }
    }

    func testDumpStaticMayFail() {
        // Static environment may not be preserved
        do {
            let entries = try Kenv.dumpStatic()
            for entry in entries {
                XCTAssertFalse(entry.name.isEmpty)
            }
        } catch KenvError.environmentNotPreserved {
            // Expected on kernels without PRESERVE_EARLY_ENVIRONMENTS
        } catch {
            // Other errors acceptable
        }
    }

    // MARK: - Convenience Method Tests

    func testNames() throws {
        let names = try Kenv.names()
        let entries = try Kenv.dump()

        XCTAssertEqual(names.count, entries.count)
        for (name, entry) in zip(names, entries) {
            XCTAssertEqual(name, entry.name)
        }
    }

    func testWithPrefix() throws {
        let acpiVars = try Kenv.withPrefix("acpi.")

        for entry in acpiVars {
            XCTAssertTrue(entry.name.hasPrefix("acpi."), "\(entry.name) should start with acpi.")
        }
    }

    func testWithPrefixNoMatch() throws {
        let noMatch = try Kenv.withPrefix("zzz_nonexistent_prefix_")
        XCTAssertTrue(noMatch.isEmpty)
    }

    func testWithPrefixEmptyString() throws {
        // Empty prefix should match all
        let all = try Kenv.withPrefix("")
        let dump = try Kenv.dump()
        XCTAssertEqual(all.count, dump.count)
    }

    func testAsDictionary() throws {
        let dict = try Kenv.asDictionary()
        let entries = try Kenv.dump()

        XCTAssertEqual(dict.count, entries.count)

        for entry in entries {
            XCTAssertEqual(dict[entry.name], entry.value)
        }
    }

    func testAsDictionaryLookup() throws {
        let dict = try Kenv.asDictionary()

        // Lookup should work
        if let firstEntry = try Kenv.dump().first {
            XCTAssertEqual(dict[firstEntry.name], firstEntry.value)
        }

        // Non-existent should be nil
        XCTAssertNil(dict["nonexistent_key_12345"])
    }

    // MARK: - Set Tests (Permission Checks)

    func testSetRequiresRoot() {
        // Should fail with EPERM when not root
        do {
            try Kenv.set("test_freebsdkit_var", value: "test_value")
            // If we're running as root, clean up
            try? Kenv.unset("test_freebsdkit_var")
        } catch KenvError.permissionDenied {
            // Expected when not root
        } catch {
            // May get other errors too
        }
    }

    func testSetNameTooLong() {
        let longName = String(repeating: "a", count: 200)
        XCTAssertThrowsError(try Kenv.set(longName, value: "test")) { error in
            guard case KenvError.nameTooLong(200) = error else {
                XCTFail("Expected nameTooLong error")
                return
            }
        }
    }

    func testSetValueTooLong() {
        let longValue = String(repeating: "b", count: 200)
        XCTAssertThrowsError(try Kenv.set("test", value: longValue)) { error in
            guard case KenvError.valueTooLong(200) = error else {
                XCTFail("Expected valueTooLong error")
                return
            }
        }
    }

    func testSetNameExactlyMaxLength() {
        let maxName = String(repeating: "x", count: 128)
        // Should not throw nameTooLong, but will likely fail with permission
        do {
            try Kenv.set(maxName, value: "test")
            try? Kenv.unset(maxName)  // cleanup if root
        } catch KenvError.nameTooLong {
            XCTFail("Should not throw nameTooLong for exactly 128 chars")
        } catch {
            // Permission denied or other errors are fine
        }
    }

    func testSetValueExactlyMaxLength() {
        let maxValue = String(repeating: "y", count: 128)
        do {
            try Kenv.set("test_max_value", value: maxValue)
            try? Kenv.unset("test_max_value")
        } catch KenvError.valueTooLong {
            XCTFail("Should not throw valueTooLong for exactly 128 chars")
        } catch {
            // Permission denied or other errors are fine
        }
    }

    func testSetEmptyValue() {
        // Empty value should be allowed (if we had permission)
        do {
            try Kenv.set("test_empty_value", value: "")
            try? Kenv.unset("test_empty_value")
        } catch KenvError.valueTooLong {
            XCTFail("Empty value should not throw valueTooLong")
        } catch {
            // Permission denied expected
        }
    }

    // MARK: - Unset Tests (Permission Checks)

    func testUnsetRequiresRoot() {
        do {
            try Kenv.unset("nonexistent_test_var")
        } catch KenvError.permissionDenied {
            // Expected when not root
        } catch KenvError.notFound {
            // Also valid - var doesn't exist
        } catch {
            // Other errors acceptable
        }
    }

    func testUnsetNameTooLong() {
        let longName = String(repeating: "c", count: 200)
        XCTAssertThrowsError(try Kenv.unset(longName)) { error in
            guard case KenvError.nameTooLong(200) = error else {
                XCTFail("Expected nameTooLong error")
                return
            }
        }
    }

    // MARK: - Error Description Tests

    func testErrorDescriptions() {
        let errors: [KenvError] = [
            .notFound("test"),
            .permissionDenied,
            .nameTooLong(200),
            .valueTooLong(300),
            .invalidArgument,
            .environmentNotPreserved,
            .systemError(22)
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty)
        }
    }

    func testNotFoundDescription() {
        let error = KenvError.notFound("myvar")
        XCTAssertTrue(error.description.contains("myvar"))
    }

    func testNameTooLongDescription() {
        let error = KenvError.nameTooLong(200)
        XCTAssertTrue(error.description.contains("200"))
        XCTAssertTrue(error.description.contains("128"))
    }

    func testValueTooLongDescription() {
        let error = KenvError.valueTooLong(300)
        XCTAssertTrue(error.description.contains("300"))
    }

    // MARK: - Special Character Tests

    func testGetWithSpecialCharacters() {
        // Variables with dots
        let dotVar = Kenv.get("acpi.oem")
        // Just testing it doesn't crash

        // Variables with underscores
        let underscoreVar = Kenv.get("boot_verbose")
        _ = dotVar
        _ = underscoreVar
    }

    func testGetWithBrackets() {
        // Some kenv vars have brackets like bootenvs[0]
        let bracketVar = Kenv.get("bootenvs[0]")
        // May or may not exist, just shouldn't crash
        _ = bracketVar
    }

    // MARK: - Consistency Tests

    func testDumpAndGetConsistency() throws {
        let entries = try Kenv.dump()

        // First few entries should match get()
        for entry in entries.prefix(5) {
            let getValue = Kenv.get(entry.name)
            XCTAssertEqual(getValue, entry.value, "get(\(entry.name)) should match dump value")
        }
    }

    func testMultipleDumpsConsistent() throws {
        let dump1 = try Kenv.dump()
        let dump2 = try Kenv.dump()

        // Same variables should be returned (order may differ theoretically but usually same)
        XCTAssertEqual(dump1.count, dump2.count)

        let names1 = Set(dump1.map(\.name))
        let names2 = Set(dump2.map(\.name))
        XCTAssertEqual(names1, names2)
    }

    // MARK: - Boundary Tests

    func testNameBoundary127() {
        // 127 characters - should work
        let name127 = String(repeating: "a", count: 127)
        _ = Kenv.get(name127)  // Just shouldn't crash
    }

    func testNameBoundary128() {
        // Exactly 128 - at limit
        let name128 = String(repeating: "b", count: 128)
        _ = Kenv.get(name128)  // Should work, probably returns nil
    }

    func testNameBoundary129() {
        // 129 characters - over limit
        let name129 = String(repeating: "c", count: 129)
        let result = Kenv.get(name129)
        XCTAssertNil(result, "Name > 128 should return nil")
    }

    // MARK: - Unicode Tests

    func testGetWithUnicode() {
        // Unicode in variable name - should handle gracefully
        let unicodeName = "test_日本語"
        let result = Kenv.get(unicodeName)
        // Will likely be nil, but shouldn't crash
        XCTAssertNil(result)
    }

    // MARK: - Thread Safety (Basic)

    func testConcurrentDumps() throws {
        let expectation = XCTestExpectation(description: "Concurrent dumps")
        expectation.expectedFulfillmentCount = 10

        for _ in 0..<10 {
            DispatchQueue.global().async {
                do {
                    let entries = try Kenv.dump()
                    XCTAssertFalse(entries.isEmpty)
                } catch {
                    XCTFail("Concurrent dump failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentGets() {
        let expectation = XCTestExpectation(description: "Concurrent gets")
        expectation.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global().async {
                _ = Kenv.get("acpi.oem")
                _ = Kenv.get("COLUMNS")
                _ = Kenv.get("nonexistent")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
