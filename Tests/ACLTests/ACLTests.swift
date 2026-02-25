/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import ACL

final class ACLTests: XCTestCase {

    // MARK: - ACL Creation Tests

    func testACLInit() throws {
        // An empty ACL is not valid until it has required entries
        var acl = try ACL(count: 4)

        // Add required entries to make it valid
        let userObj = try acl.createEntry()
        try userObj.setTag(.userObj)
        try userObj.setPermissions(.all)

        let groupObj = try acl.createEntry()
        try groupObj.setTag(.groupObj)
        try groupObj.setPermissions(.readExecute)

        let other = try acl.createEntry()
        try other.setTag(.other)
        try other.setPermissions([.read])

        XCTAssertTrue(acl.isValid)
    }

    func testACLFromMode() {
        guard let acl = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL from mode")
            return
        }
        XCTAssertEqual(acl.brand, .posix)
        XCTAssertTrue(acl.isTrivial)
    }

    func testACLFromText() {
        guard let acl = ACL.fromText("user::rwx,group::r-x,other::r-x") else {
            XCTFail("Failed to create ACL from text")
            return
        }
        XCTAssertEqual(acl.brand, .posix)
    }

    func testACLDuplicate() throws {
        guard let original = ACL.fromMode(0o644) else {
            XCTFail("Failed to create ACL")
            return
        }
        let copy = try original.duplicate()
        XCTAssertTrue(original.isEqual(to: copy))
    }

    // MARK: - ACL Text Conversion Tests

    func testACLToText() {
        guard let acl = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL")
            return
        }
        let text = acl.text
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("user::"))
        XCTAssertTrue(text!.contains("group::"))
        XCTAssertTrue(text!.contains("other::"))
    }

    func testACLTextOutput() {
        guard let acl = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL")
            return
        }
        let text = acl.text
        XCTAssertNotNil(text)
        XCTAssertFalse(text!.isEmpty)
    }

    // MARK: - ACL Properties Tests

    func testACLBrand() {
        guard let posixACL = ACL.fromMode(0o644) else {
            XCTFail("Failed to create ACL")
            return
        }
        XCTAssertEqual(posixACL.brand, .posix)
    }

    func testACLIsTrivial() {
        guard let trivial = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL")
            return
        }
        XCTAssertTrue(trivial.isTrivial)
    }

    func testACLEquivalentMode() {
        guard let acl = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL")
            return
        }
        let mode = acl.equivalentMode
        XCTAssertNotNil(mode)
        XCTAssertEqual(mode! & 0o777, 0o755)
    }

    // MARK: - Entry Iteration Tests

    func testACLIteration() {
        guard let acl = ACL.fromMode(0o755) else {
            XCTFail("Failed to create ACL")
            return
        }

        var entryCount = 0
        var hasUserObj = false
        var hasGroupObj = false
        var hasOther = false

        acl.forEachEntry { entry in
            entryCount += 1
            switch entry.tag {
            case .userObj:
                hasUserObj = true
                XCTAssertTrue(entry.permissions.contains(.read))
                XCTAssertTrue(entry.permissions.contains(.write))
                XCTAssertTrue(entry.permissions.contains(.execute))
            case .groupObj:
                hasGroupObj = true
                XCTAssertTrue(entry.permissions.contains(.read))
                XCTAssertFalse(entry.permissions.contains(.write))
                XCTAssertTrue(entry.permissions.contains(.execute))
            case .other:
                hasOther = true
                XCTAssertTrue(entry.permissions.contains(.read))
                XCTAssertFalse(entry.permissions.contains(.write))
                XCTAssertTrue(entry.permissions.contains(.execute))
            default:
                break
            }
        }

        XCTAssertEqual(entryCount, 3)
        XCTAssertTrue(hasUserObj)
        XCTAssertTrue(hasGroupObj)
        XCTAssertTrue(hasOther)
    }

    func testACLEntriesArray() {
        guard let acl = ACL.fromMode(0o644) else {
            XCTFail("Failed to create ACL")
            return
        }

        let entries = acl.entries
        XCTAssertEqual(entries.count, 3)
    }

    // MARK: - Entry Modification Tests

    func testCreateEntry() throws {
        var acl = try ACL()
        let entry = try acl.createEntry()
        try entry.setTag(.userObj)
        try entry.setPermissions(.all)
        XCTAssertEqual(entry.tag, .userObj)
        XCTAssertEqual(entry.permissions, .all)
    }

    func testEntryPermissions() throws {
        var acl = try ACL()
        let entry = try acl.createEntry()
        try entry.setTag(.userObj)

        try entry.setPermissions([.read, .execute])
        XCTAssertTrue(entry.permissions.contains(.read))
        XCTAssertFalse(entry.permissions.contains(.write))
        XCTAssertTrue(entry.permissions.contains(.execute))

        try entry.setPermissions(.all)
        XCTAssertEqual(entry.permissions, .all)

        try entry.setPermissions([])
        XCTAssertEqual(entry.permissions, [])
    }

    // MARK: - Permission OptionSet Tests

    func testPermissionsOptionSet() {
        let readWrite: ACLEntry.Permissions = [.read, .write]
        XCTAssertTrue(readWrite.contains(.read))
        XCTAssertTrue(readWrite.contains(.write))
        XCTAssertFalse(readWrite.contains(.execute))

        XCTAssertEqual(ACLEntry.Permissions.all, [.read, .write, .execute])
        XCTAssertEqual(ACLEntry.Permissions.readExecute, [.read, .execute])
    }

    func testPermissionsDescription() {
        let rwx = ACLEntry.Permissions.all
        XCTAssertEqual(rwx.description, "rwx")

        let rx: ACLEntry.Permissions = [.read, .execute]
        XCTAssertEqual(rx.description, "r-x")

        let none: ACLEntry.Permissions = []
        XCTAssertEqual(none.description, "---")
    }

    // MARK: - Tag Tests

    func testEntryTagTypes() throws {
        var acl = try ACL()

        let userObj = try acl.createEntry()
        try userObj.setTag(.userObj)
        XCTAssertEqual(userObj.tag, .userObj)

        let groupObj = try acl.createEntry()
        try groupObj.setTag(.groupObj)
        XCTAssertEqual(groupObj.tag, .groupObj)

        let other = try acl.createEntry()
        try other.setTag(.other)
        XCTAssertEqual(other.tag, .other)
    }

    // MARK: - Qualifier Tests

    func testEntryQualifier() throws {
        var acl = try ACL()
        let entry = try acl.createEntry()
        try entry.setTag(.user)
        try entry.setQualifier(1000)

        XCTAssertEqual(entry.qualifier, 1000)
    }

    func testQualifierOnlyForUserGroup() throws {
        var acl = try ACL()
        let entry = try acl.createEntry()
        try entry.setTag(.userObj)
        XCTAssertNil(entry.qualifier)
    }

    // MARK: - Builder Tests

    func testACLBuilder() throws {
        var builder = ACL.builder()
        _ = builder.ownerPermissions(.all)
        _ = builder.groupPermissions(.readExecute)
        _ = builder.otherPermissions([.read])

        let acl = try builder.build()
        XCTAssertTrue(acl.isValid)
        XCTAssertEqual(acl.brand, .posix)
    }

    func testACLBuilderWithExtendedEntries() throws {
        var builder = ACL.builder()
        _ = builder.ownerPermissions(.all)
        _ = builder.userPermissions(1000, .readWrite)
        _ = builder.groupPermissions(.readExecute)
        _ = builder.groupPermissions(100, [.read])
        _ = builder.otherPermissions([.read])

        let acl = try builder.build()
        XCTAssertTrue(acl.isValid)

        // Should have mask entry due to extended entries
        var hasMask = false
        acl.forEachEntry { entry in
            if entry.tag == .mask {
                hasMask = true
            }
        }
        XCTAssertTrue(hasMask)
    }

    // MARK: - File Operations Tests (requires temp file)

    // Note: These tests require a filesystem that supports ACLs.
    // On systems where /tmp doesn't support ACLs, these tests will be skipped.

    func testGetSetACL() throws {
        // Create a temp file
        let tempPath = "/tmp/acl_test_\(getpid())"
        let fd = open(tempPath, O_CREAT | O_WRONLY, 0o644)
        guard fd >= 0 else {
            throw ACL.Error(errno: errno)
        }
        close(fd)
        defer { unlink(tempPath) }

        // Try to get the ACL - skip if not supported
        do {
            let acl = try ACL.get(path: tempPath)
            XCTAssertTrue(acl.isValid)
            XCTAssertEqual(acl.brand, .posix)

            // Modify and set back
            guard let newACL = ACL.fromMode(0o755) else {
                XCTFail("Failed to create ACL")
                return
            }
            try newACL.set(path: tempPath)

            // Verify
            let verify = try ACL.get(path: tempPath)
            if let mode = verify.equivalentMode {
                XCTAssertEqual(mode & 0o777, 0o755)
            }
        } catch let error as ACL.Error where error.errno == EOPNOTSUPP || error.errno == EINVAL {
            // ACLs not supported on this filesystem, skip test
            print("Skipping testGetSetACL: ACLs not supported on /tmp")
        }
    }

    func testGetACLByFD() throws {
        let tempPath = "/tmp/acl_fd_test_\(getpid())"
        let fd = open(tempPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            throw ACL.Error(errno: errno)
        }
        defer {
            close(fd)
            unlink(tempPath)
        }

        do {
            let acl = try ACL.get(fd: fd)
            XCTAssertTrue(acl.isValid)
        } catch let error as ACL.Error where error.errno == EOPNOTSUPP || error.errno == EINVAL {
            // ACLs not supported on this filesystem, skip test
            print("Skipping testGetACLByFD: ACLs not supported on /tmp")
        }
    }

    func testHasExtendedACL() throws {
        let tempPath = "/tmp/acl_ext_test_\(getpid())"
        let fd = open(tempPath, O_CREAT | O_WRONLY, 0o644)
        guard fd >= 0 else {
            throw ACL.Error(errno: errno)
        }
        close(fd)
        defer { unlink(tempPath) }

        // Basic file shouldn't have extended ACL
        // This may return false or error depending on filesystem support
        _ = ACL.hasExtendedACL(path: tempPath)
    }

    func testACLStripped() throws {
        var builder = ACL.builder()
        _ = builder.ownerPermissions(.all)
        _ = builder.userPermissions(1000, .readWrite)
        _ = builder.groupPermissions(.readExecute)
        _ = builder.otherPermissions([.read])

        let acl = try builder.build()
        let stripped = try acl.stripped()

        // Stripped should only have base entries (may include mask)
        let entries = stripped.entries
        // Base entries: user_obj, group_obj, other (and possibly mask)
        XCTAssertGreaterThanOrEqual(entries.count, 3)
        XCTAssertLessThanOrEqual(entries.count, 4)

        // Should not have extended user/group entries
        for entry in entries {
            XCTAssertTrue(
                entry.tag == .userObj || entry.tag == .groupObj ||
                entry.tag == .other || entry.tag == .mask
            )
        }
    }

    // MARK: - ACL Type Tests

    func testACLTypes() {
        XCTAssertEqual(ACLType.access.rawValue, 0x00000002)
        XCTAssertEqual(ACLType.default.rawValue, 0x00000003)
        XCTAssertEqual(ACLType.nfs4.rawValue, 0x00000004)
    }

    // MARK: - ACL Brand Tests

    func testACLBrands() {
        XCTAssertEqual(ACL.Brand.unknown.rawValue, 0)
        XCTAssertEqual(ACL.Brand.posix.rawValue, 1)
        XCTAssertEqual(ACL.Brand.nfs4.rawValue, 2)
    }

    // MARK: - NFSv4 Permission Tests

    func testNFS4Permissions() {
        let full = ACLEntry.NFS4Permissions.fullSet
        XCTAssertTrue(full.contains(.readData))
        XCTAssertTrue(full.contains(.writeData))
        XCTAssertTrue(full.contains(.execute))
        XCTAssertTrue(full.contains(.delete))

        let readSet = ACLEntry.NFS4Permissions.readSet
        XCTAssertTrue(readSet.contains(.readData))
        XCTAssertTrue(readSet.contains(.readACL))
        XCTAssertFalse(readSet.contains(.writeData))
    }

    // MARK: - NFSv4 Entry Type Tests

    func testNFS4EntryTypes() {
        XCTAssertEqual(ACLEntry.EntryType.allow.rawValue, 0x0100)
        XCTAssertEqual(ACLEntry.EntryType.deny.rawValue, 0x0200)
        XCTAssertEqual(ACLEntry.EntryType.audit.rawValue, 0x0400)
        XCTAssertEqual(ACLEntry.EntryType.alarm.rawValue, 0x0800)
    }

    // MARK: - NFSv4 Flags Tests

    func testNFS4Flags() {
        let inheritFlags: ACLEntry.Flags = [.fileInherit, .directoryInherit]
        XCTAssertTrue(inheritFlags.contains(.fileInherit))
        XCTAssertTrue(inheritFlags.contains(.directoryInherit))
        XCTAssertFalse(inheritFlags.contains(.inheritOnly))
    }

    // MARK: - Error Tests

    func testACLErrorEquatable() {
        XCTAssertEqual(ACL.Error.notPermitted, ACL.Error.notPermitted)
        XCTAssertNotEqual(ACL.Error.notPermitted, ACL.Error.invalidArgument)
    }

    func testACLErrorDescription() {
        let error = ACL.Error(errno: EPERM)
        XCTAssertFalse(error.description.isEmpty)
    }

    func testGetNonExistentFile() {
        do {
            _ = try ACL.get(path: "/nonexistent/path/file")
            XCTFail("Should have thrown an error")
        } catch let error as ACL.Error {
            XCTAssertEqual(error.errno, ENOENT)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
