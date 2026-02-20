/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
@testable import FreeBSDKit

// Forward declare sysctlbyname for direct C API calls
@_silgen_name("sysctlbyname")
private func sysctlbyname(
    _ name: UnsafePointer<CChar>,
    _ oldp: UnsafeMutableRawPointer?,
    _ oldlenp: UnsafeMutablePointer<Int>,
    _ newp: UnsafeRawPointer?,
    _ newlen: Int
) -> Int32

final class SysctlTests: XCTestCase {

    // MARK: - Int32 Tests

    func testGetInt32_SeqpacketMax() throws {
        // Get value using C API
        var cValue: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let cResult = "net.local.seqpacket.maxseqpacket".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: Int32 = try Sysctl.get("net.local.seqpacket.maxseqpacket")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for Int32 value")
        XCTAssertGreaterThan(swiftValue, 0, "SEQPACKET max should be positive")
    }

    func testGetInt32_DatagramMax() throws {
        // Get value using C API
        var cValue: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let cResult = "net.local.dgram.maxdgram".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: Int32 = try Sysctl.get("net.local.dgram.maxdgram")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for Int32 value")
        XCTAssertGreaterThan(swiftValue, 0, "DGRAM max should be positive")
    }

    func testGetInt32_OSReldate() throws {
        // Get value using C API
        var cValue: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let cResult = "kern.osreldate".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: Int32 = try Sysctl.get("kern.osreldate")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for Int32 value")
        XCTAssertGreaterThan(swiftValue, 1000000, "OS release date should be reasonable")
    }

    // MARK: - Int64 Tests

    func testGetInt64_Physmem() throws {
        // Get value using C API
        var cValue: Int64 = 0
        var size = MemoryLayout<Int64>.size
        let cResult = "hw.physmem".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: Int64 = try Sysctl.get("hw.physmem")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for Int64 value")
        XCTAssertGreaterThan(swiftValue, 0, "Physical memory should be positive")
    }

    func testGetInt64_Usermem() throws {
        // Get value using C API
        var cValue: Int64 = 0
        var size = MemoryLayout<Int64>.size
        let cResult = "hw.usermem".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: Int64 = try Sysctl.get("hw.usermem")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for Int64 value")
        XCTAssertGreaterThan(swiftValue, 0, "User memory should be positive")
    }

    // MARK: - String Tests

    func testGetString_Hostname() throws {
        // Get value using C API
        var cBuffer = [CChar](repeating: 0, count: 256)
        var size = cBuffer.count
        let cResult = "kern.hostname".withCString { namePtr in
            sysctlbyname(namePtr, &cBuffer, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")
        let cValue = String(cString: cBuffer)

        // Get value using Swift API
        let swiftValue = try Sysctl.getString("kern.hostname")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for string value")
        XCTAssertFalse(swiftValue.isEmpty, "Hostname should not be empty")
    }

    func testGetString_OSType() throws {
        // Get value using C API
        var cBuffer = [CChar](repeating: 0, count: 256)
        var size = cBuffer.count
        let cResult = "kern.ostype".withCString { namePtr in
            sysctlbyname(namePtr, &cBuffer, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")
        let cValue = String(cString: cBuffer)

        // Get value using Swift API
        let swiftValue = try Sysctl.getString("kern.ostype")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for string value")
        XCTAssertEqual(swiftValue, "FreeBSD", "OS type should be FreeBSD")
    }

    func testGetString_OSRelease() throws {
        // Get value using C API
        var cBuffer = [CChar](repeating: 0, count: 256)
        var size = cBuffer.count
        let cResult = "kern.osrelease".withCString { namePtr in
            sysctlbyname(namePtr, &cBuffer, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")
        let cValue = String(cString: cBuffer)

        // Get value using Swift API
        let swiftValue = try Sysctl.getString("kern.osrelease")

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Swift API should match C API for string value")
        XCTAssertFalse(swiftValue.isEmpty, "OS release should not be empty")
    }

    // MARK: - Struct Tests

    func testGetStruct_Boottime() throws {
        // Get value using C API
        var cValue = timeval()
        var size = MemoryLayout<timeval>.size
        let cResult = "kern.boottime".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using Swift API
        let swiftValue: timeval = try Sysctl.get("kern.boottime")

        // Compare
        XCTAssertEqual(swiftValue.tv_sec, cValue.tv_sec, "Swift API tv_sec should match C API")
        XCTAssertEqual(swiftValue.tv_usec, cValue.tv_usec, "Swift API tv_usec should match C API")
        XCTAssertGreaterThan(swiftValue.tv_sec, 0, "Boot time should be positive")
    }

    // MARK: - Subscript Tests

    func testSubscript_Int32() throws {
        // Get value using C API
        var cValue: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let cResult = "net.local.seqpacket.maxseqpacket".withCString { namePtr in
            sysctlbyname(namePtr, &cValue, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")

        // Get value using subscript
        let swiftValue: Int32 = try Sysctl["net.local.seqpacket.maxseqpacket"]

        // Compare
        XCTAssertEqual(swiftValue, cValue, "Subscript should match C API")
    }

    func testSubscript_String() throws {
        // Get value using C API
        var cBuffer = [CChar](repeating: 0, count: 256)
        var size = cBuffer.count
        let cResult = "kern.hostname".withCString { namePtr in
            sysctlbyname(namePtr, &cBuffer, &size, nil, 0)
        }
        XCTAssertEqual(cResult, 0, "C API call should succeed")
        let cValue = String(cString: cBuffer)

        // Get value using subscript
        let swiftValue: String = try Sysctl.string["kern.hostname"]

        // Compare
        XCTAssertEqual(swiftValue, cValue, "String subscript should match C API")
    }

    // MARK: - Error Handling

    func testGetInvalidSysctl() {
        // Test that invalid sysctl names throw errors
        XCTAssertThrowsError(try Sysctl.getString("invalid.sysctl.name")) { error in
            XCTAssertTrue(error is BSDError, "Should throw BSDError")
        }
    }

    func testGetStringInvalidSysctl() {
        // Test that invalid sysctl names throw errors for getString
        XCTAssertThrowsError(try Sysctl.getString("invalid.sysctl.name")) { error in
            XCTAssertTrue(error is BSDError, "Should throw BSDError")
        }
    }

}
