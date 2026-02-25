/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Descriptors
@testable import Cpuset

final class CpusetTests: XCTestCase {

    // MARK: - CPUSet Tests

    func testCPUSetInit() {
        let set = CPUSet()
        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.count, 0)
    }

    func testCPUSetSingleCPU() {
        let set = CPUSet(cpu: 0)
        XCTAssertFalse(set.isEmpty)
        XCTAssertEqual(set.count, 1)
        XCTAssertTrue(set.isSet(cpu: 0))
        XCTAssertFalse(set.isSet(cpu: 1))
    }

    func testCPUSetMultipleCPUs() {
        let set = CPUSet(cpus: [0, 2, 4])
        XCTAssertEqual(set.count, 3)
        XCTAssertTrue(set.isSet(cpu: 0))
        XCTAssertFalse(set.isSet(cpu: 1))
        XCTAssertTrue(set.isSet(cpu: 2))
        XCTAssertFalse(set.isSet(cpu: 3))
        XCTAssertTrue(set.isSet(cpu: 4))
    }

    func testCPUSetRange() {
        let set = CPUSet(range: 0..<4)
        XCTAssertEqual(set.count, 4)
        XCTAssertEqual(set.cpus, [0, 1, 2, 3])
    }

    func testCPUSetMutations() {
        var set = CPUSet()
        XCTAssertTrue(set.isEmpty)

        set.set(cpu: 5)
        XCTAssertTrue(set.isSet(cpu: 5))
        XCTAssertEqual(set.count, 1)

        set.set(cpu: 10)
        XCTAssertEqual(set.count, 2)

        set.clear(cpu: 5)
        XCTAssertFalse(set.isSet(cpu: 5))
        XCTAssertEqual(set.count, 1)

        set.clear()
        XCTAssertTrue(set.isEmpty)
    }

    func testCPUSetFill() {
        var set = CPUSet()
        set.fill()
        XCTAssertTrue(set.isFull)
        XCTAssertFalse(set.isEmpty)
    }

    func testCPUSetFirst() {
        var set = CPUSet()
        XCTAssertNil(set.first)

        set.set(cpu: 5)
        XCTAssertEqual(set.first, 5)

        set.set(cpu: 2)
        XCTAssertEqual(set.first, 2)
    }

    func testCPUSetLast() {
        var set = CPUSet()
        XCTAssertNil(set.last)

        set.set(cpu: 5)
        XCTAssertEqual(set.last, 5)

        set.set(cpu: 10)
        XCTAssertEqual(set.last, 10)
    }

    func testCPUSetUnion() {
        let set1 = CPUSet(cpus: [0, 1])
        let set2 = CPUSet(cpus: [2, 3])
        let union = set1.union(set2)
        XCTAssertEqual(union.cpus, [0, 1, 2, 3])
    }

    func testCPUSetIntersection() {
        let set1 = CPUSet(cpus: [0, 1, 2])
        let set2 = CPUSet(cpus: [1, 2, 3])
        let intersection = set1.intersection(set2)
        XCTAssertEqual(intersection.cpus, [1, 2])
    }

    func testCPUSetSubtracting() {
        let set1 = CPUSet(cpus: [0, 1, 2, 3])
        let set2 = CPUSet(cpus: [1, 3])
        let diff = set1.subtracting(set2)
        XCTAssertEqual(diff.cpus, [0, 2])
    }

    func testCPUSetEquality() {
        let set1 = CPUSet(cpus: [0, 1, 2])
        let set2 = CPUSet(cpus: [0, 1, 2])
        let set3 = CPUSet(cpus: [0, 1])
        XCTAssertEqual(set1, set2)
        XCTAssertNotEqual(set1, set3)
    }

    func testCPUSetDescription() {
        let empty = CPUSet()
        XCTAssertEqual(empty.description, "CPUSet(empty)")

        let set = CPUSet(cpus: [0, 2])
        XCTAssertEqual(set.description, "CPUSet(0, 2)")
    }

    // MARK: - DomainSet Tests

    func testDomainSetInit() {
        let set = DomainSet()
        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.count, 0)
    }

    func testDomainSetSingle() {
        let set = DomainSet(domain: 0)
        XCTAssertFalse(set.isEmpty)
        XCTAssertEqual(set.count, 1)
        XCTAssertTrue(set.isSet(domain: 0))
    }

    func testDomainSetMutations() {
        var set = DomainSet()
        set.set(domain: 0)
        XCTAssertTrue(set.isSet(domain: 0))

        set.clear(domain: 0)
        XCTAssertFalse(set.isSet(domain: 0))
    }

    // MARK: - Level Tests

    func testLevelValues() {
        XCTAssertEqual(Cpuset.Level.root.rawValue, 1)
        XCTAssertEqual(Cpuset.Level.cpuset.rawValue, 2)
        XCTAssertEqual(Cpuset.Level.which.rawValue, 3)
    }

    // MARK: - Which Tests

    func testWhichValues() {
        XCTAssertEqual(Cpuset.Which.thread.rawValue, 1)
        XCTAssertEqual(Cpuset.Which.process.rawValue, 2)
        XCTAssertEqual(Cpuset.Which.cpuset.rawValue, 3)
        XCTAssertEqual(Cpuset.Which.irq.rawValue, 4)
        XCTAssertEqual(Cpuset.Which.jail.rawValue, 5)
    }

    // MARK: - Target Tests

    func testTargetCurrentThread() {
        let target = Cpuset.Target.currentThread
        XCTAssertEqual(target.which, .thread)
        XCTAssertEqual(target.id, -1)
    }

    func testTargetCurrentProcess() {
        let target = Cpuset.Target.currentProcess
        XCTAssertEqual(target.which, .process)
        XCTAssertEqual(target.id, 0)
    }

    func testTargetProcess() {
        let target = Cpuset.Target.process(1234)
        XCTAssertEqual(target.which, .process)
        XCTAssertEqual(target.id, 1234)
    }

    func testTargetJail() {
        let target = Cpuset.Target.jail(5)
        XCTAssertEqual(target.which, .jail)
        XCTAssertEqual(target.id, 5)
    }

    // MARK: - CpusetID Tests

    func testCpusetIDDefault() {
        let id = Cpuset.CpusetID.default
        XCTAssertEqual(id.rawValue, 0)
        XCTAssertTrue(id.isValid)
    }

    func testCpusetIDInvalid() {
        let id = Cpuset.CpusetID.invalid
        XCTAssertEqual(id.rawValue, -1)
        XCTAssertFalse(id.isValid)
    }

    func testCpusetIDDescription() {
        let valid = Cpuset.CpusetID(5)
        XCTAssertEqual(valid.description, "CpusetID(5)")

        let invalid = Cpuset.CpusetID.invalid
        XCTAssertEqual(invalid.description, "CpusetID(invalid)")
    }

    // MARK: - DomainPolicy Tests

    func testDomainPolicyValues() {
        XCTAssertEqual(DomainPolicy.roundRobin.rawValue, 1)
        XCTAssertEqual(DomainPolicy.firstTouch.rawValue, 2)
        XCTAssertEqual(DomainPolicy.prefer.rawValue, 3)
        XCTAssertEqual(DomainPolicy.interleave.rawValue, 4)
    }

    // MARK: - Error Tests

    func testErrorEquatable() {
        XCTAssertEqual(Cpuset.Error.notPermitted, Cpuset.Error.notPermitted)
        XCTAssertNotEqual(Cpuset.Error.notPermitted, Cpuset.Error.invalidArgument)
    }

    func testErrorDescription() {
        let error = Cpuset.Error(errno: EPERM)
        XCTAssertFalse(error.description.isEmpty)
    }

    func testErrorPresets() {
        XCTAssertEqual(Cpuset.Error.notPermitted.errno, EPERM)
        XCTAssertEqual(Cpuset.Error.noSuchProcess.errno, ESRCH)
        XCTAssertEqual(Cpuset.Error.invalidArgument.errno, EINVAL)
        XCTAssertEqual(Cpuset.Error.notFound.errno, ENOENT)
    }

    // MARK: - System Tests

    func testGetAffinityCurrentThread() {
        do {
            let affinity = try Cpuset.getAffinity(for: .currentThread)
            // Should have at least one CPU
            XCTAssertFalse(affinity.isEmpty)
            XCTAssertGreaterThan(affinity.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetAffinityCurrentProcess() {
        do {
            let affinity = try Cpuset.getAffinity(for: .currentProcess)
            XCTAssertFalse(affinity.isEmpty)
        } catch let error as Cpuset.Error where error.errno == EPERM {
            print("Skipping testGetAffinityCurrentProcess: requires elevated privileges")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAvailableCPUs() {
        do {
            let cpus = try Cpuset.availableCPUs()
            XCTAssertFalse(cpus.isEmpty)
            let count = try Cpuset.availableCPUCount()
            XCTAssertEqual(cpus.count, count)
        } catch let error as Cpuset.Error where error.errno == EPERM {
            print("Skipping testAvailableCPUs: requires elevated privileges")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootCPUs() {
        do {
            let root = try Cpuset.rootCPUs()
            let available = try Cpuset.getAffinity(level: .cpuset, for: .currentThread)
            // Available should be subset of or equal to root
            XCTAssertGreaterThanOrEqual(root.count, available.count)
        } catch let error as Cpuset.Error where error.errno == EPERM {
            print("Skipping testRootCPUs: requires elevated privileges")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetCpusetId() {
        do {
            // Use cpuset level to get the cpuset ID for the thread
            let id = try Cpuset.getId(level: .cpuset, for: .currentThread)
            XCTAssertTrue(id.isValid)
        } catch let error as Cpuset.Error where error.errno == EPERM || error.errno == EINVAL {
            print("Skipping testGetCpusetId: requires elevated privileges or not supported")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSetAffinityCurrentThread() {
        do {
            // Get current affinity
            let original = try Cpuset.getAffinity(for: .currentThread)

            // Try to set to first available CPU
            if let first = original.first {
                let restricted = CPUSet(cpu: first)
                try Cpuset.setAffinity(restricted, for: .currentThread)

                // Verify
                let current = try Cpuset.getAffinity(for: .currentThread)
                XCTAssertEqual(current.count, 1)
                XCTAssertTrue(current.isSet(cpu: first))

                // Restore
                try Cpuset.setAffinity(original, for: .currentThread)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPinCurrentThread() {
        do {
            let original = try Cpuset.getAffinity(for: .currentThread)

            if let first = original.first {
                try Cpuset.pinCurrentThread(to: first)

                let current = try Cpuset.getAffinity(for: .currentThread)
                XCTAssertEqual(current.count, 1)

                // Restore
                try Cpuset.resetCurrentThreadAffinity()
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDomainOperations() {
        do {
            // Get current domain policy
            let (domains, policy) = try Cpuset.getDomain(for: .currentThread)

            // Just verify we can read without error
            // Domain count depends on system configuration
            _ = domains.count
            _ = policy

        } catch let error as Cpuset.Error {
            // EINVAL may occur on systems without NUMA
            if error.errno != EINVAL {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
