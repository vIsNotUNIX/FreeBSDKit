/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import Descriptors

final class DeviceDescriptorTests: XCTestCase {

    // MARK: - DeviceTypeFlags Tests

    func testDeviceTypeFlagsRawValues() {
        // Just verify the flags exist and have distinct non-zero values
        XCTAssertNotEqual(DeviceTypeFlags.disk.rawValue, 0)
        XCTAssertNotEqual(DeviceTypeFlags.tty.rawValue, 0)
        XCTAssertNotEqual(DeviceTypeFlags.mem.rawValue, 0)

        XCTAssertNotEqual(DeviceTypeFlags.disk.rawValue, DeviceTypeFlags.tty.rawValue)
        XCTAssertNotEqual(DeviceTypeFlags.disk.rawValue, DeviceTypeFlags.mem.rawValue)
        XCTAssertNotEqual(DeviceTypeFlags.tty.rawValue, DeviceTypeFlags.mem.rawValue)
    }

    func testDeviceTypeFlagsOptionSet() {
        var flags: DeviceTypeFlags = []
        XCTAssertTrue(flags.isEmpty)

        flags.insert(.disk)
        XCTAssertTrue(flags.contains(.disk))
        XCTAssertFalse(flags.contains(.tty))

        flags.insert(.tty)
        XCTAssertTrue(flags.contains(.disk))
        XCTAssertTrue(flags.contains(.tty))
    }

    // MARK: - DescriptorKind Tests

    func testDescriptorKindDeviceCase() {
        let kind = DescriptorKind.device
        XCTAssertEqual(kind, .device)
        XCTAssertNotEqual(kind, .file)
        XCTAssertNotEqual(kind, .directory)
    }
}
