/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import FPC
@testable import Descriptors

final class DescriptorKindWireTests: XCTestCase {

    // MARK: - Wire Value Tests

    func testWireValueForAllKinds() {
        // Verify each kind has a unique wire value
        let kinds: [DescriptorKind] = [
            .unknown,
            .file,
            .directory,
            .device,
            .process,
            .kqueue,
            .socket,
            .pipe,
            .jail(owning: false),
            .jail(owning: true),
            .shm,
            .event
        ]

        var seenValues = Set<UInt8>()
        for kind in kinds {
            let value = kind.wireValue
            XCTAssertFalse(seenValues.contains(value), "Duplicate wire value \(value) for \(kind)")
            seenValues.insert(value)
        }
    }

    func testDeviceWireValue() {
        XCTAssertEqual(DescriptorKind.device.wireValue, 3)
    }

    func testDeviceFromWireValue() {
        let kind = DescriptorKind.fromWireValue(3)
        XCTAssertEqual(kind, .device)
    }

    func testWireValueRoundTrip() {
        let kinds: [DescriptorKind] = [
            .file,
            .directory,
            .device,
            .process,
            .kqueue,
            .socket,
            .pipe,
            .jail(owning: false),
            .jail(owning: true),
            .shm,
            .event
        ]

        for kind in kinds {
            let wireValue = kind.wireValue
            let decoded = DescriptorKind.fromWireValue(wireValue)
            XCTAssertEqual(decoded, kind, "Round-trip failed for \(kind)")
        }
    }

    func testUnknownWireValue() {
        XCTAssertEqual(DescriptorKind.unknown.wireValue, 0)
        XCTAssertEqual(DescriptorKind.fromWireValue(0), .unknown)
    }

    func testInvalidWireValueReturnsUnknown() {
        // Any value not in the defined range should return unknown
        XCTAssertEqual(DescriptorKind.fromWireValue(200), .unknown)
        XCTAssertEqual(DescriptorKind.fromWireValue(254), .unknown)
    }

    func testOOLPayloadWireValue() {
        XCTAssertEqual(DescriptorKind.oolPayloadWireValue, 255)
        // 255 should decode to unknown (it's a special marker, not a kind)
        XCTAssertEqual(DescriptorKind.fromWireValue(255), .unknown)
    }
}
