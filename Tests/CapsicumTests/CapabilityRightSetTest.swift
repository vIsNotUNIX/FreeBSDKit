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
import CCapsicum
@testable import Capsicum

final class CapsicumRightSetTests: XCTestCase {

    // MARK: - Single Rights

    func testAddingSingleRight() {
        var set = CapsicumRightSet()
        set.add(capability: .read)
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertFalse(set.contains(capability: .write))
    }

    func testRemovingSingleRight() {
        var set = CapsicumRightSet(rights: [.read, .write])
        set.clear(capability: .read)
        
        XCTAssertFalse(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
    }

    // MARK: - Multiple Rights

    func testAddingMultipleRights() {
        var set = CapsicumRightSet()
        set.add(capabilities: [.read, .write, .seek])
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertTrue(set.contains(capability: .seek))
        XCTAssertFalse(set.contains(capability: .accept))
    }


    func testRemovingMultipleRights() {
        var set = CapsicumRightSet(rights: [.read, .write, .seek])
        set.clear(capabilities: [.read, .seek])
        
        XCTAssertFalse(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertFalse(set.contains(capability: .seek))
    }

    // MARK: - Merging Sets

    func testMergeSets() {
        var set1 = CapsicumRightSet(rights: [.read, .write])
        let set2 = CapsicumRightSet(rights: [.seek, .accept])
        
        set1.merge(with: set2)
        
        XCTAssertTrue(set1.contains(capability: .read))
        XCTAssertTrue(set1.contains(capability: .write))
        XCTAssertTrue(set1.contains(capability: .seek))
        XCTAssertTrue(set1.contains(capability: .accept))
    }

    func testRemoveMatchingSet() {
        var set1 = CapsicumRightSet(rights: [.read, .write, .seek])
        let set2 = CapsicumRightSet(rights: [.write, .seek])
        
        set1.remove(matching: set2)
        
        XCTAssertTrue(set1.contains(capability: .read))
        XCTAssertFalse(set1.contains(capability: .write))
        XCTAssertFalse(set1.contains(capability: .seek))
    }

    // MARK: - Validation

    func testValidation() {
        var set = CapsicumRightSet(rights: [.read, .write])
        XCTAssertTrue(set.validate())
    }

    // MARK: - Copying / Containment

    func testContainsOtherSet() {
        let set1 = CapsicumRightSet(rights: [.read, .write, .seek])
        let set2 = CapsicumRightSet(rights: [.write, .seek])
        
        XCTAssertTrue(set1.contains(right: set2))
        
        let set3 = CapsicumRightSet(rights: [.write, .accept])
        XCTAssertFalse(set1.contains(right: set3))
    }

    func testInitFromArray() {
        let set = CapsicumRightSet(rights: [.read, .write, .seek])
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertTrue(set.contains(capability: .seek))
        XCTAssertFalse(set.contains(capability: .accept))
    }

    func testInitFromOtherSet() {
        let original = CapsicumRightSet(rights: [.read, .write])
        let copy = CapsicumRightSet(from: original)
        
        XCTAssertTrue(copy.contains(capability: .read))
        XCTAssertTrue(copy.contains(capability: .write))
    }

    func testInitWithRawRights() {
        // Create a raw cap_rights_t and add a right manually
        var rawRights = cap_rights_t()
        ccapsicum_rights_init(&rawRights)
        ccapsicum_cap_set(&rawRights, CapsicumRight.read.bridged)
        ccapsicum_cap_set(&rawRights, CapsicumRight.write.bridged)
        
        // Initialize CapsicumRightSet with the raw struct
        let set = CapsicumRightSet(rights: rawRights)
        
        // Assert that the rights are present
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertFalse(set.contains(capability: .seek))
    }

    func testTakeReturnsUnderlyingRights() {
        var set = CapsicumRightSet()
        set.add(capability: .read)
        set.add(capability: .write)
        
        let raw = set.rawBSD
        
        // Create a new set from the raw struct and check it contains same rights
        let newSet = CapsicumRightSet(rights: raw)
        XCTAssertTrue(newSet.contains(capability: .read))
        XCTAssertTrue(newSet.contains(capability: .write))
        XCTAssertFalse(newSet.contains(capability: .seek))
    }
}