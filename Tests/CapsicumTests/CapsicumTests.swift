/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import Capsicum

final class CapsicumTests: XCTestCase {

    func testInitialStatusIsNotInCapabilityMode() throws {
        let status = try Capsicum.status()
        XCTAssertFalse(
            status,
            "Process should not start in Capsicum capability mode"
        )
    }

    // MARK: - IOCTL Tests

    func testGetIoctlsOnUnlimitedFd() throws {
        let fd = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open /dev/null")
        defer { close(fd) }

        // An unlimited fd should report all ioctls allowed
        XCTAssertThrowsError(try CapsicumHelper.getIoctls(fd: fd)) { error in
            XCTAssertEqual(
                error as? CapsicumIoctlError,
                CapsicumIoctlError.allIoctlsAllowed,
                "Expected allIoctlsAllowed for unlimited fd"
            )
        }
    }

    func testLimitIoctlsToEmpty() throws {
        let fd = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open /dev/null")
        defer { close(fd) }

        // Limit to no ioctls
        try CapsicumHelper.limitIoctls(fd: fd, commands: [])

        // Now getIoctls should return empty array
        let cmds = try CapsicumHelper.getIoctls(fd: fd)
        XCTAssertTrue(cmds.isEmpty, "Expected empty ioctl list after limiting to none")
    }

    func testLimitIoctlsToSpecificCommands() throws {
        let fd = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open /dev/null")
        defer { close(fd) }

        // Limit to specific ioctl commands
        let testCommands: [IoctlCommand] = [
            IoctlCommand(rawValue: 0x20006601),  // FIOCLEX
            IoctlCommand(rawValue: 0x20006602),  // FIONCLEX
        ]

        try CapsicumHelper.limitIoctls(fd: fd, commands: testCommands)

        // Verify we get back the same commands
        let cmds = try CapsicumHelper.getIoctls(fd: fd)
        XCTAssertEqual(cmds.count, 2, "Expected 2 allowed ioctl commands")

        let rawValues = Set(cmds.map(\.rawValue))
        XCTAssertTrue(rawValues.contains(0x20006601), "Expected FIOCLEX in result")
        XCTAssertTrue(rawValues.contains(0x20006602), "Expected FIONCLEX in result")
    }

    func testLimitIoctlsCannotExpand() throws {
        let fd = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0, "Failed to open /dev/null")
        defer { close(fd) }

        // First limit to one ioctl
        try CapsicumHelper.limitIoctls(fd: fd, commands: [IoctlCommand(rawValue: 0x20006601)])

        // Attempting to expand should fail with ENOTCAPABLE
        XCTAssertThrowsError(try CapsicumHelper.limitIoctls(fd: fd, commands: [
            IoctlCommand(rawValue: 0x20006601),
            IoctlCommand(rawValue: 0x20006602),
        ])) { error in
            // Should get an error (ENOTCAPABLE = attempting to expand rights)
            XCTAssertNotNil(error, "Should throw when trying to expand ioctl rights")
        }
    }

    func testGetIoctlsOnInvalidFd() {
        XCTAssertThrowsError(try CapsicumHelper.getIoctls(fd: -1)) { error in
            XCTAssertEqual(
                error as? CapsicumIoctlError,
                CapsicumIoctlError.invalidDescriptor,
                "Expected invalidDescriptor for bad fd"
            )
        }
    }
}
