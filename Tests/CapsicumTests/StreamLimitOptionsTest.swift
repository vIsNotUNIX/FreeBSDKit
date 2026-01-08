//
//  StreamLimitOptionsTests.swift
//  FreeBSDKitTests
//
//  Created by Kory Heard on 2026-01-03.
//

import XCTest
@testable import Capsicum
@testable import CCapsicum

final class StreamLimitOptionsTests: XCTestCase {

    func testIndividualOptions() {
        XCTAssertEqual(StreamLimitOptions.ignoreBadFileDescriptor.rawValue, CAPH_IGNORE_EBADF)
        XCTAssertEqual(StreamLimitOptions.read.rawValue, CAPH_READ)
        XCTAssertEqual(StreamLimitOptions.write.rawValue, CAPH_WRITE)
    }

    func testOptionSetContains() {
        let options: StreamLimitOptions = [.read, .write]
        XCTAssertTrue(options.contains(.read))
        XCTAssertTrue(options.contains(.write))
        XCTAssertFalse(options.contains(.ignoreBadFileDescriptor))
    }

    func testOptionSetUnion() {
        var options: StreamLimitOptions = [.read]
        options.insert(.write)
        XCTAssertTrue(options.contains(.read))
        XCTAssertTrue(options.contains(.write))
    }

    func testOptionSetRawValueRoundTrip() {
        let combinedRaw = CAPH_READ | CAPH_WRITE
        let options = StreamLimitOptions(rawValue: combinedRaw)
        XCTAssertTrue(options.contains(.read))
        XCTAssertTrue(options.contains(.write))
    }
}
