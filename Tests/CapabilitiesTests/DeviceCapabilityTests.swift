/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import Capabilities
@testable import Descriptors

final class DeviceCapabilityTests: XCTestCase {

    // MARK: - Basic Open/Close Tests

    func testOpenDevNull() throws {
        let device = try DeviceCapability.open(path: "/dev/null", flags: [.readWrite])
        device.close()
    }

    func testOpenDevZero() throws {
        let device = try DeviceCapability.open(path: "/dev/zero", flags: [.readOnly])
        device.close()
    }

    func testOpenDevRandom() throws {
        let device = try DeviceCapability.open(path: "/dev/random", flags: [.readOnly])
        device.close()
    }

    func testOpenNonexistentDeviceFails() {
        do {
            let device = try DeviceCapability.open(path: "/dev/nonexistent_device_12345")
            device.close()
            XCTFail("Expected open to fail for nonexistent device")
        } catch {
            // Expected
        }
    }

    // MARK: - Read/Write Tests

    func testReadFromDevZero() throws {
        var device = try DeviceCapability.open(path: "/dev/zero", flags: [.readOnly])

        let result = try device.read(maxBytes: 16)
        device.close()

        switch result {
        case .data(let data):
            XCTAssertEqual(data.count, 16)
            XCTAssertTrue(data.allSatisfy { $0 == 0 })
        case .eof:
            XCTFail("/dev/zero should not return EOF")
        }
    }

    func testReadFromDevRandom() throws {
        var device = try DeviceCapability.open(path: "/dev/random", flags: [.readOnly])

        let result = try device.read(maxBytes: 32)
        device.close()

        switch result {
        case .data(let data):
            XCTAssertEqual(data.count, 32)
        case .eof:
            XCTFail("/dev/random should not return EOF")
        }
    }

    func testWriteToDevNull() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.writeOnly])

        let data = Data("Hello, /dev/null!".utf8)
        let written = try device.writeOnce(data)
        device.close()

        XCTAssertEqual(written, data.count)
    }

    // MARK: - IOCTL Tests

    func testBytesAvailableOnDevZero() throws {
        var device = try DeviceCapability.open(path: "/dev/zero", flags: [.readOnly])

        do {
            let bytes = try device.bytesAvailable()
            device.close()
            XCTAssertGreaterThanOrEqual(bytes, 0)
        } catch {
            device.close()
            // ENOTTY is acceptable
        }
    }

    func testSetNonBlocking() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.readWrite])

        do {
            try device.setNonBlocking(true)
            try device.setNonBlocking(false)
        } catch {
            // Some devices may not support this
        }
        device.close()
    }

    // MARK: - Device Type Tests

    func testDeviceTypeOnDevNull() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.readOnly])

        do {
            let deviceType = try device.deviceType()
            _ = deviceType
        } catch {
            // ENOTTY is acceptable
        }
        device.close()
    }

    func testIsDiskOnDevNull() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.readOnly])

        do {
            let isDisk = try device.isDisk()
            device.close()
            XCTAssertFalse(isDisk, "/dev/null should not be a disk device")
        } catch {
            device.close()
            // ENOTTY is acceptable
        }
    }

    // MARK: - Stat Tests

    func testStatOnDevice() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.readOnly])

        let st = try device.stat()
        device.close()

        XCTAssertTrue((st.st_mode & S_IFMT) == S_IFCHR, "/dev/null should be a character device")
    }

    // MARK: - Sync Test

    func testSyncOnDevNull() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.writeOnly])

        try device.sync()
        device.close()
    }

    // MARK: - Duplicate Test

    func testDuplicateDevice() throws {
        var device = try DeviceCapability.open(path: "/dev/null", flags: [.readWrite])

        var dup = try device.duplicate()

        let data = Data("test".utf8)
        let written1 = try device.writeOnce(data)
        let written2 = try dup.writeOnce(data)

        device.close()
        dup.close()

        XCTAssertEqual(written1, data.count)
        XCTAssertEqual(written2, data.count)
    }
}
