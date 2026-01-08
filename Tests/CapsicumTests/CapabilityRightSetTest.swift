import XCTest
import CCapsicum
@testable import Capsicum

final class CapabilityRightSetTests: XCTestCase {

    // MARK: - Single Rights

    func testAddingSingleRight() {
        var set = CapabilityRightSet()
        set.add(capability: .read)
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertFalse(set.contains(capability: .write))
    }

    func testRemovingSingleRight() {
        var set = CapabilityRightSet(rights: [.read, .write])
        set.clear(capability: .read)
        
        XCTAssertFalse(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
    }

    // MARK: - Multiple Rights

    func testAddingMultipleRights() {
        var set = CapabilityRightSet()
        set.add(capabilities: [.read, .write, .seek])
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertTrue(set.contains(capability: .seek))
        XCTAssertFalse(set.contains(capability: .accept))
    }


    func testRemovingMultipleRights() {
        var set = CapabilityRightSet(rights: [.read, .write, .seek])
        set.clear(capabilities: [.read, .seek])
        
        XCTAssertFalse(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertFalse(set.contains(capability: .seek))
    }

    // MARK: - Merging Sets

    func testMergeSets() {
        var set1 = CapabilityRightSet(rights: [.read, .write])
        let set2 = CapabilityRightSet(rights: [.seek, .accept])
        
        set1.merge(with: set2)
        
        XCTAssertTrue(set1.contains(capability: .read))
        XCTAssertTrue(set1.contains(capability: .write))
        XCTAssertTrue(set1.contains(capability: .seek))
        XCTAssertTrue(set1.contains(capability: .accept))
    }

    func testRemoveMatchingSet() {
        var set1 = CapabilityRightSet(rights: [.read, .write, .seek])
        let set2 = CapabilityRightSet(rights: [.write, .seek])
        
        set1.remove(matching: set2)
        
        XCTAssertTrue(set1.contains(capability: .read))
        XCTAssertFalse(set1.contains(capability: .write))
        XCTAssertFalse(set1.contains(capability: .seek))
    }

    // MARK: - Validation

    func testValidation() {
        var set = CapabilityRightSet(rights: [.read, .write])
        XCTAssertTrue(set.validate())
    }

    // MARK: - Copying / Containment

    func testContainsOtherSet() {
        let set1 = CapabilityRightSet(rights: [.read, .write, .seek])
        let set2 = CapabilityRightSet(rights: [.write, .seek])
        
        XCTAssertTrue(set1.contains(right: set2))
        
        let set3 = CapabilityRightSet(rights: [.write, .accept])
        XCTAssertFalse(set1.contains(right: set3))
    }

    func testInitFromArray() {
        let set = CapabilityRightSet(rights: [.read, .write, .seek])
        
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertTrue(set.contains(capability: .seek))
        XCTAssertFalse(set.contains(capability: .accept))
    }

    func testInitFromOtherSet() {
        let original = CapabilityRightSet(rights: [.read, .write])
        let copy = CapabilityRightSet(from: original)
        
        XCTAssertTrue(copy.contains(capability: .read))
        XCTAssertTrue(copy.contains(capability: .write))
    }

    func testInitWithRawRights() {
        // Create a raw cap_rights_t and add a right manually
        var rawRights = cap_rights_t()
        ccapsicum_rights_init(&rawRights)
        ccapsicum_cap_set(&rawRights, CapabilityRight.read.bridged)
        ccapsicum_cap_set(&rawRights, CapabilityRight.write.bridged)
        
        // Initialize CapabilityRightSet with the raw struct
        let set = CapabilityRightSet(rights: rawRights)
        
        // Assert that the rights are present
        XCTAssertTrue(set.contains(capability: .read))
        XCTAssertTrue(set.contains(capability: .write))
        XCTAssertFalse(set.contains(capability: .seek))
    }

    func testTakeReturnsUnderlyingRights() {
        var set = CapabilityRightSet()
        set.add(capability: .read)
        set.add(capability: .write)
        
        let raw = set.asBSDType()
        
        // Create a new set from the raw struct and check it contains same rights
        let newSet = CapabilityRightSet(rights: raw)
        XCTAssertTrue(newSet.contains(capability: .read))
        XCTAssertTrue(newSet.contains(capability: .write))
        XCTAssertFalse(newSet.contains(capability: .seek))
    }
}