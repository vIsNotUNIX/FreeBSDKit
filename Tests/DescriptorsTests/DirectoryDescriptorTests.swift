/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import Descriptors
@testable import FreeBSDKit

// MARK: - Mode Helpers

/// Check if mode indicates a directory.
private func isDirectory(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFDIR
}

/// Check if mode indicates a regular file.
private func isRegularFile(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFREG
}

/// Check if mode indicates a symbolic link.
private func isSymlink(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFLNK
}

/// Check if mode indicates a FIFO.
private func isFIFO(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFIFO
}

// MARK: - Test Descriptor Types

/// A simple file descriptor for testing Descriptor protocol methods.
struct TestFileDescriptor: Descriptor {
    typealias RAWBSD = Int32
    private let fd: Int32

    init(_ fd: Int32) {
        self.fd = fd
    }

    consuming func close() {
        Glibc.close(fd)
    }

    consuming func take() -> Int32 {
        return fd
    }

    func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

/// A directory descriptor for testing DirectoryDescriptor protocol methods.
struct TestDirectoryDescriptor: DirectoryDescriptor {
    typealias RAWBSD = Int32
    private let fd: Int32

    init(_ fd: Int32) {
        self.fd = fd
    }

    consuming func close() {
        Glibc.close(fd)
    }

    consuming func take() -> Int32 {
        return fd
    }

    func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R where R: ~Copyable {
        try block(fd)
    }
}

// MARK: - DirectoryEntryType Tests

final class DirectoryEntryTypeTests: XCTestCase {

    func testDirectoryEntryTypeValues() {
        XCTAssertEqual(DirectoryEntryType.unknown.rawValue, 0)
        XCTAssertEqual(DirectoryEntryType.fifo.rawValue, 1)
        XCTAssertEqual(DirectoryEntryType.characterDevice.rawValue, 2)
        XCTAssertEqual(DirectoryEntryType.directory.rawValue, 4)
        XCTAssertEqual(DirectoryEntryType.blockDevice.rawValue, 6)
        XCTAssertEqual(DirectoryEntryType.regular.rawValue, 8)
        XCTAssertEqual(DirectoryEntryType.symbolicLink.rawValue, 10)
        XCTAssertEqual(DirectoryEntryType.socket.rawValue, 12)
        XCTAssertEqual(DirectoryEntryType.whiteout.rawValue, 14)
    }

    func testDirectoryEntryTypeFromDtype() {
        XCTAssertEqual(DirectoryEntryType(dtype: 0), .unknown)
        XCTAssertEqual(DirectoryEntryType(dtype: 4), .directory)
        XCTAssertEqual(DirectoryEntryType(dtype: 8), .regular)
        XCTAssertEqual(DirectoryEntryType(dtype: 10), .symbolicLink)
        // Unknown value maps to unknown
        XCTAssertEqual(DirectoryEntryType(dtype: 99), .unknown)
    }
}

// MARK: - DirectoryEntry Tests

final class DirectoryEntryTests: XCTestCase {

    func testDirectoryEntryInit() {
        let entry = DirectoryEntry(inode: 12345, type: .regular, name: "test.txt")
        XCTAssertEqual(entry.inode, 12345)
        XCTAssertEqual(entry.type, .regular)
        XCTAssertEqual(entry.name, "test.txt")
    }

    func testDirectoryEntrySendable() {
        let entry = DirectoryEntry(inode: 1, type: .directory, name: "subdir")
        // Verify it can be sent across concurrency boundaries
        let _: Sendable = entry
        XCTAssertEqual(entry.name, "subdir")
    }
}

// MARK: - Descriptor Metadata Tests

final class DescriptorMetadataTests: XCTestCase {
    var tempDir: String!
    var testFile: String!

    override func setUp() {
        super.setUp()
        tempDir = "/tmp/descriptor_test_\(ProcessInfo.processInfo.processIdentifier)"
        mkdir(tempDir, 0o755)
        testFile = "\(tempDir!)/testfile"
        // Create test file
        let fd = open(testFile, O_CREAT | O_WRONLY, 0o644)
        if fd >= 0 {
            write(fd, "test", 4)
            Glibc.close(fd)
        }
    }

    override func tearDown() {
        // Clean up
        if let testFile = testFile {
            unlink(testFile)
        }
        if let tempDir = tempDir {
            rmdir(tempDir)
        }
        super.tearDown()
    }

    func testChmod() throws {
        let fd = open(testFile, O_RDWR)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open test file")
        let desc = TestFileDescriptor(fd)

        // Change to 0o600
        try desc.chmod(mode: 0o600)

        // Verify with stat
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_mode & 0o777, 0o600)

        // Change back to 0o644
        try desc.chmod(mode: 0o644)
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_mode & 0o777, 0o644)

        desc.close()
    }

    func testChflags() throws {
        let fd = open(testFile, O_RDWR)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open test file")
        let desc = TestFileDescriptor(fd)

        // Set UF_NODUMP (user flag, doesn't require root)
        let UF_NODUMP: UInt = 0x00000001
        try desc.chflags(flags: UF_NODUMP)

        // Verify with stat
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_flags & UInt32(UF_NODUMP), UInt32(UF_NODUMP))

        // Clear the flag
        try desc.chflags(flags: 0)
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_flags & UInt32(UF_NODUMP), 0)

        desc.close()
    }

    func testSetTimes() throws {
        let fd = open(testFile, O_RDWR)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open test file")
        let desc = TestFileDescriptor(fd)

        // Set specific times (Jan 1, 2020)
        let accessTime = timespec(tv_sec: 1577836800, tv_nsec: 0)
        let modTime = timespec(tv_sec: 1577836800, tv_nsec: 0)
        try desc.setTimes(access: accessTime, modification: modTime)

        // Verify with stat
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_atim.tv_sec, 1577836800)
        XCTAssertEqual(st.st_mtim.tv_sec, 1577836800)

        desc.close()
    }

    func testTouchTimes() throws {
        let fd = open(testFile, O_RDWR)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open test file")
        let desc = TestFileDescriptor(fd)

        // First set times to past
        let pastTime = timespec(tv_sec: 1000000000, tv_nsec: 0)
        try desc.setTimes(access: pastTime, modification: pastTime)

        // Now touch
        let beforeTouch = time(nil)
        try desc.touchTimes()
        let afterTouch = time(nil)

        // Verify times are recent
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertGreaterThanOrEqual(st.st_atim.tv_sec, beforeTouch)
        XCTAssertLessThanOrEqual(st.st_atim.tv_sec, afterTouch + 1)
        XCTAssertGreaterThanOrEqual(st.st_mtim.tv_sec, beforeTouch)
        XCTAssertLessThanOrEqual(st.st_mtim.tv_sec, afterTouch + 1)

        desc.close()
    }

    func testChownSameUser() throws {
        // This test changes ownership to the same user (should always succeed)
        let fd = open(testFile, O_RDWR)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open test file")
        let desc = TestFileDescriptor(fd)

        let currentUid = getuid()
        let currentGid = getgid()

        // Set to current user/group (should succeed)
        try desc.chown(owner: currentUid, group: currentGid)

        // Verify ownership unchanged
        var st = Glibc.stat()
        XCTAssertEqual(Glibc.fstat(fd, &st), 0)
        XCTAssertEqual(st.st_uid, currentUid)
        XCTAssertEqual(st.st_gid, currentGid)

        desc.close()
    }
}

// MARK: - DirectoryDescriptor Tests

final class DirectoryDescriptorTests: XCTestCase {
    var tempDir: String!
    var dirDesc: TestDirectoryDescriptor!

    override func setUp() {
        super.setUp()
        tempDir = "/tmp/dirtest_\(ProcessInfo.processInfo.processIdentifier)"
        mkdir(tempDir, 0o755)
        let fd = open(tempDir, O_RDONLY | O_DIRECTORY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open temp directory")
        dirDesc = TestDirectoryDescriptor(fd)
    }

    override func tearDown() {
        dirDesc?.close()
        // Clean up temp directory
        if let tempDir = tempDir {
            // Remove any files
            let dp = opendir(tempDir)
            if dp != nil {
                while let entry = readdir(dp) {
                    let name = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                        String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                    }
                    if name != "." && name != ".." {
                        unlink("\(tempDir)/\(name)")
                    }
                }
                closedir(dp)
            }
            rmdir(tempDir)
        }
        super.tearDown()
    }

    // MARK: - File Operations

    func testOpenFileAndStat() throws {
        // Create a file
        let fd = try dirDesc.openFile(path: "newfile.txt", flags: [.writeOnly, .create], mode: 0o644)
        XCTAssertGreaterThanOrEqual(fd, 0)
        write(fd, "hello", 5)
        Glibc.close(fd)

        // Stat it
        let st = try dirDesc.stat(path: "newfile.txt")
        XCTAssertEqual(st.st_size, 5)
        XCTAssertEqual(st.st_mode & 0o777, 0o644)

        // Clean up
        try dirDesc.unlink(path: "newfile.txt")
    }

    func testMkdirAndRmdir() throws {
        try dirDesc.mkdir(path: "subdir", mode: 0o755)

        let st = try dirDesc.stat(path: "subdir")
        XCTAssertTrue(isDirectory(st.st_mode))
        XCTAssertEqual(st.st_mode & 0o777, 0o755)

        try dirDesc.unlink(path: "subdir", flags: [.removeDir])
    }

    func testRename() throws {
        // Create file
        let fd = try dirDesc.openFile(path: "original.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        // Rename
        try dirDesc.rename(from: "original.txt", to: "renamed.txt")

        // Verify old doesn't exist
        XCTAssertThrowsError(try dirDesc.stat(path: "original.txt"))

        // Verify new exists
        let st = try dirDesc.stat(path: "renamed.txt")
        XCTAssertTrue(isRegularFile(st.st_mode))

        try dirDesc.unlink(path: "renamed.txt")
    }

    func testSymlinkAndReadlink() throws {
        // Create target file
        let fd = try dirDesc.openFile(path: "target.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        // Create symlink
        try dirDesc.symlink(target: "target.txt", path: "link.txt")

        // Read symlink
        let target = try dirDesc.readlink(path: "link.txt")
        XCTAssertEqual(target, "target.txt")

        // Stat symlink (should be symlink type)
        let st = try dirDesc.stat(path: "link.txt", flags: [.symlinkNoFollow])
        XCTAssertTrue(isSymlink(st.st_mode))

        try dirDesc.unlink(path: "link.txt")
        try dirDesc.unlink(path: "target.txt")
    }

    func testHardLink() throws {
        // Create target file
        let fd = try dirDesc.openFile(path: "original.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        // Create hard link
        try dirDesc.link(from: "original.txt", to: "hardlink.txt")

        // Verify same inode
        let st1 = try dirDesc.stat(path: "original.txt")
        let st2 = try dirDesc.stat(path: "hardlink.txt")
        XCTAssertEqual(st1.st_ino, st2.st_ino)
        XCTAssertEqual(st1.st_nlink, 2)

        try dirDesc.unlink(path: "hardlink.txt")
        try dirDesc.unlink(path: "original.txt")
    }

    // MARK: - Metadata Operations

    func testChmodAt() throws {
        let fd = try dirDesc.openFile(path: "modtest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        try dirDesc.chmod(path: "modtest.txt", mode: 0o600)

        let st = try dirDesc.stat(path: "modtest.txt")
        XCTAssertEqual(st.st_mode & 0o777, 0o600)

        try dirDesc.unlink(path: "modtest.txt")
    }

    func testChflagsAt() throws {
        let fd = try dirDesc.openFile(path: "flagtest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        let UF_NODUMP: UInt = 0x00000001
        try dirDesc.chflags(path: "flagtest.txt", flags: UF_NODUMP)

        let st = try dirDesc.stat(path: "flagtest.txt")
        XCTAssertEqual(st.st_flags & UInt32(UF_NODUMP), UInt32(UF_NODUMP))

        try dirDesc.chflags(path: "flagtest.txt", flags: 0)
        try dirDesc.unlink(path: "flagtest.txt")
    }

    func testSetTimesAt() throws {
        let fd = try dirDesc.openFile(path: "timetest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        let testTime = timespec(tv_sec: 1577836800, tv_nsec: 0)
        try dirDesc.setTimes(path: "timetest.txt", access: testTime, modification: testTime)

        let st = try dirDesc.stat(path: "timetest.txt")
        XCTAssertEqual(st.st_atim.tv_sec, 1577836800)
        XCTAssertEqual(st.st_mtim.tv_sec, 1577836800)

        try dirDesc.unlink(path: "timetest.txt")
    }

    func testChownAt() throws {
        let fd = try dirDesc.openFile(path: "owntest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        let currentUid = getuid()
        let currentGid = getgid()

        // Set to same user/group (should succeed)
        try dirDesc.chown(path: "owntest.txt", owner: currentUid, group: currentGid)

        let st = try dirDesc.stat(path: "owntest.txt")
        XCTAssertEqual(st.st_uid, currentUid)
        XCTAssertEqual(st.st_gid, currentGid)

        try dirDesc.unlink(path: "owntest.txt")
    }

    func testAccess() throws {
        let fd = try dirDesc.openFile(path: "accesstest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        // Check readable
        let canRead = try dirDesc.access(path: "accesstest.txt", mode: R_OK)
        XCTAssertTrue(canRead)

        // Check writable
        let canWrite = try dirDesc.access(path: "accesstest.txt", mode: W_OK)
        XCTAssertTrue(canWrite)

        // Check non-existent file
        let noExist = try dirDesc.access(path: "nonexistent.txt", mode: F_OK)
        XCTAssertFalse(noExist)

        try dirDesc.unlink(path: "accesstest.txt")
    }

    // MARK: - Special Files

    func testMkfifo() throws {
        try dirDesc.mkfifo(path: "testfifo", mode: 0o644)

        let st = try dirDesc.stat(path: "testfifo")
        XCTAssertTrue(isFIFO(st.st_mode))
        XCTAssertEqual(st.st_mode & 0o777, 0o644)

        try dirDesc.unlink(path: "testfifo")
    }

    // Note: mknod typically requires root, so we skip testing it for device nodes

    // MARK: - Directory Reading

    func testReadEntries() throws {
        // Create some files
        for i in 0..<5 {
            let fd = try dirDesc.openFile(path: "file\(i).txt", flags: [.writeOnly, .create], mode: 0o644)
            Glibc.close(fd)
        }
        try dirDesc.mkdir(path: "subdir")

        // Read entries
        let entries = try dirDesc.readEntries()

        // Should have at least . and .. plus our files
        XCTAssertGreaterThanOrEqual(entries.count, 7)

        // Find our files
        let names = Set(entries.map { $0.name })
        XCTAssertTrue(names.contains("."))
        XCTAssertTrue(names.contains(".."))
        XCTAssertTrue(names.contains("file0.txt"))
        XCTAssertTrue(names.contains("file4.txt"))
        XCTAssertTrue(names.contains("subdir"))

        // Check types
        let subdirEntry = entries.first { $0.name == "subdir" }
        XCTAssertNotNil(subdirEntry)
        XCTAssertEqual(subdirEntry?.type, .directory)

        let fileEntry = entries.first { $0.name == "file0.txt" }
        XCTAssertNotNil(fileEntry)
        XCTAssertEqual(fileEntry?.type, .regular)

        // Clean up
        for i in 0..<5 {
            try dirDesc.unlink(path: "file\(i).txt")
        }
        try dirDesc.unlink(path: "subdir", flags: [.removeDir])
    }

    func testReadEntriesEmpty() throws {
        // Read entries from directory with only . and ..
        let entries = try dirDesc.readEntries()

        // Should have at least . and ..
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        let names = Set(entries.map { $0.name })
        XCTAssertTrue(names.contains("."))
        XCTAssertTrue(names.contains(".."))
    }

    func testReadEntriesRaw() throws {
        // Create a file
        let fd = try dirDesc.openFile(path: "rawtest.txt", flags: [.writeOnly, .create], mode: 0o644)
        Glibc.close(fd)

        // Test raw reading
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 8)
        defer { buffer.deallocate() }

        // Seek to beginning
        _ = dirDesc.unsafe { fd in
            lseek(fd, 0, SEEK_SET)
        }

        var basep: off_t = 0
        let bytesRead = try dirDesc.readEntriesRaw(into: buffer, basep: &basep)

        XCTAssertGreaterThan(bytesRead, 0)

        try dirDesc.unlink(path: "rawtest.txt")
    }
}

// MARK: - AtFlags and OpenAtFlags Tests

final class FlagTests: XCTestCase {

    func testOpenAtFlagsValues() {
        XCTAssertEqual(OpenAtFlags.readOnly.rawValue, O_RDONLY)
        XCTAssertEqual(OpenAtFlags.writeOnly.rawValue, O_WRONLY)
        XCTAssertEqual(OpenAtFlags.readWrite.rawValue, O_RDWR)
        XCTAssertEqual(OpenAtFlags.create.rawValue, O_CREAT)
        XCTAssertEqual(OpenAtFlags.truncate.rawValue, O_TRUNC)
        XCTAssertEqual(OpenAtFlags.append.rawValue, O_APPEND)
        XCTAssertEqual(OpenAtFlags.closeOnExec.rawValue, O_CLOEXEC)
        XCTAssertEqual(OpenAtFlags.directory.rawValue, O_DIRECTORY)
        XCTAssertEqual(OpenAtFlags.noFollow.rawValue, O_NOFOLLOW)
    }

    func testOpenAtFlagsOptionSet() {
        let flags: OpenAtFlags = [.readWrite, .create, .truncate]
        XCTAssertTrue(flags.contains(.readWrite))
        XCTAssertTrue(flags.contains(.create))
        XCTAssertTrue(flags.contains(.truncate))
        XCTAssertFalse(flags.contains(.append))
    }

    func testAtFlagsValues() {
        XCTAssertEqual(AtFlags.symlinkNoFollow.rawValue, AT_SYMLINK_NOFOLLOW)
        XCTAssertEqual(AtFlags.removeDir.rawValue, AT_REMOVEDIR)
    }

    func testAtFlagsOptionSet() {
        var flags: AtFlags = []
        XCTAssertTrue(flags.isEmpty)

        flags.insert(.symlinkNoFollow)
        XCTAssertTrue(flags.contains(.symlinkNoFollow))
        XCTAssertFalse(flags.contains(.removeDir))
    }
}
