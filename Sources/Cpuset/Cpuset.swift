/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCpuset
import Glibc

/// Swift interface to FreeBSD's cpuset(2) CPU affinity subsystem.
///
/// The cpuset subsystem allows processes, threads, jails, and IRQs to be
/// bound to specific CPUs. It also provides NUMA domain affinity control.
///
/// ## Usage
///
/// ```swift
/// // Get CPU affinity for current thread
/// let affinity = try Cpuset.getAffinity()
/// print("Running on CPUs: \(affinity.cpus)")
///
/// // Pin current process to CPUs 0 and 1
/// var mask = CPUSet()
/// mask.set(cpu: 0)
/// mask.set(cpu: 1)
/// try Cpuset.setAffinity(mask, for: .currentProcess)
///
/// // Create a new cpuset
/// let setId = try Cpuset.create()
/// ```
public enum Cpuset {
    /// Gets the CPU affinity mask for a target.
    ///
    /// - Parameters:
    ///   - level: The level to query (default: which).
    ///   - target: The target to query (default: current thread).
    /// - Returns: The CPU affinity mask.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getAffinity(
        level: Level = .which,
        for target: Target = .currentThread
    ) throws -> CPUSet {
        var mask = cpuset_t()
        ccpuset_zero(&mask)

        let result = ccpuset_getaffinity(
            level.rawValue,
            target.which.rawValue,
            target.id,
            MemoryLayout<cpuset_t>.size,
            &mask
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return CPUSet(mask)
    }

    /// Sets the CPU affinity mask for a target.
    ///
    /// - Parameters:
    ///   - mask: The CPU affinity mask.
    ///   - level: The level to set (default: which).
    ///   - target: The target to modify (default: current thread).
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func setAffinity(
        _ mask: CPUSet,
        level: Level = .which,
        for target: Target = .currentThread
    ) throws {
        var rawMask = mask.rawValue

        let result = ccpuset_setaffinity(
            level.rawValue,
            target.which.rawValue,
            target.id,
            MemoryLayout<cpuset_t>.size,
            &rawMask
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Gets the NUMA domain affinity for a target.
    ///
    /// - Parameters:
    ///   - level: The level to query (default: which).
    ///   - target: The target to query (default: current thread).
    /// - Returns: A tuple of the domain mask and policy.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getDomain(
        level: Level = .which,
        for target: Target = .currentThread
    ) throws -> (domains: DomainSet, policy: DomainPolicy) {
        var mask = domainset_t()
        cdomainset_zero(&mask)
        var policy: Int32 = 0

        let result = ccpuset_getdomain(
            level.rawValue,
            target.which.rawValue,
            target.id,
            MemoryLayout<domainset_t>.size,
            &mask,
            &policy
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return (DomainSet(mask), DomainPolicy(rawValue: policy) ?? .roundRobin)
    }

    /// Sets the NUMA domain affinity for a target.
    ///
    /// - Parameters:
    ///   - domains: The domain mask.
    ///   - policy: The allocation policy.
    ///   - level: The level to set (default: which).
    ///   - target: The target to modify (default: current thread).
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func setDomain(
        _ domains: DomainSet,
        policy: DomainPolicy,
        level: Level = .which,
        for target: Target = .currentThread
    ) throws {
        var rawMask = domains.rawValue

        let result = ccpuset_setdomain(
            level.rawValue,
            target.which.rawValue,
            target.id,
            MemoryLayout<domainset_t>.size,
            &rawMask,
            policy.rawValue
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Creates a new cpuset and returns its ID.
    ///
    /// The new cpuset inherits the mask from the creating thread's cpuset.
    ///
    /// - Returns: The ID of the newly created cpuset.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func create() throws -> CpusetID {
        var setId: cpusetid_t = CCPUSET_INVALID

        let result = ccpuset_create(&setId)

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return CpusetID(setId)
    }

    /// Gets the cpuset ID for a target.
    ///
    /// - Parameters:
    ///   - level: The level to query.
    ///   - target: The target to query.
    /// - Returns: The cpuset ID.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getId(
        level: Level,
        for target: Target
    ) throws -> CpusetID {
        var setId: cpusetid_t = CCPUSET_INVALID

        let result = ccpuset_getid(
            level.rawValue,
            target.which.rawValue,
            target.id,
            &setId
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return CpusetID(setId)
    }

    /// Assigns a target to a cpuset.
    ///
    /// - Parameters:
    ///   - target: The target to assign.
    ///   - setId: The cpuset to assign to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func assign(
        _ target: Target,
        to setId: CpusetID
    ) throws {
        let result = ccpuset_setid(
            target.which.rawValue,
            target.id,
            setId.rawValue
        )

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }
}
