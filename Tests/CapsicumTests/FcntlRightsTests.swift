/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
 
import XCTest
@testable import Capsicum
@testable import CCapsicum

final class FcntlRightsTests: XCTestCase {

    // MARK: - Single Flag Initialization
    func testSingleFlagInitialization() {
        let rights = FcntlRights.getFlags
        XCTAssertEqual(rights.rawValue, UInt32(CAP_FCNTL_GETFL))
        
        let ownerRights = FcntlRights.setOwner
        XCTAssertEqual(ownerRights.rawValue, UInt32(CAP_FCNTL_SETOWN))
    }

    // MARK: - Combining Flags
    func testCombiningFlags() {
        let rights: FcntlRights = [.getFlags, .setFlags]
        XCTAssertTrue(rights.contains(.getFlags))
        XCTAssertTrue(rights.contains(.setFlags))
        XCTAssertFalse(rights.contains(.getOwner))
    }

    // MARK: - OptionSet Operations
    func testOptionSetOperations() {
        var rights: FcntlRights = []
        XCTAssertFalse(rights.contains(.getOwner))
        
        rights.insert(.getOwner)
        XCTAssertTrue(rights.contains(.getOwner))
        
        rights.remove(.getOwner)
        XCTAssertFalse(rights.contains(.getOwner))
        
        rights.formUnion([.getFlags, .setOwner])
        XCTAssertTrue(rights.contains(.getFlags))
        XCTAssertTrue(rights.contains(.setOwner))
        
        rights.subtract([.getFlags])
        XCTAssertFalse(rights.contains(.getFlags))
        XCTAssertTrue(rights.contains(.setOwner))
    }

    // MARK: - Raw Value Round-Trip
    func testRawValueRoundTrip() {
        let raw: UInt32 = UInt32(CAP_FCNTL_GETFL | CAP_FCNTL_SETOWN)
        let rights = FcntlRights(rawValue: raw)
        XCTAssertTrue(rights.contains(.getFlags))
        XCTAssertTrue(rights.contains(.setOwner))
        XCTAssertFalse(rights.contains(.setFlags))
        XCTAssertFalse(rights.contains(.getOwner))
    }
}
