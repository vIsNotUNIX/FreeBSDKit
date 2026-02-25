/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Glibc

// MARK: - Target from Descriptors

extension Cpuset.Target {
    /// Creates a target from a process descriptor.
    ///
    /// - Parameter descriptor: A process descriptor (from pdfork).
    /// - Returns: A target for the process.
    /// - Throws: If the PID cannot be retrieved from the descriptor.
    public static func process<D: ProcessDescriptor>(
        from descriptor: borrowing D
    ) throws -> Cpuset.Target where D: ~Copyable {
        .process(try descriptor.pid())
    }
}

// MARK: - Convenience Methods with Descriptors

extension Cpuset {
    /// Gets the CPU affinity for a process descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A process descriptor.
    ///   - level: The level to query (default: which).
    /// - Returns: The CPU affinity mask.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getAffinity<D: ProcessDescriptor>(
        for descriptor: borrowing D,
        level: Level = .which
    ) throws -> CPUSet where D: ~Copyable {
        try getAffinity(level: level, for: .process(from: descriptor))
    }

    /// Sets the CPU affinity for a process descriptor.
    ///
    /// - Parameters:
    ///   - mask: The CPU affinity mask.
    ///   - descriptor: A process descriptor.
    ///   - level: The level to set (default: which).
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func setAffinity<D: ProcessDescriptor>(
        _ mask: CPUSet,
        for descriptor: borrowing D,
        level: Level = .which
    ) throws where D: ~Copyable {
        try setAffinity(mask, level: level, for: .process(from: descriptor))
    }

    /// Pins a process descriptor to a single CPU.
    ///
    /// - Parameters:
    ///   - descriptor: A process descriptor.
    ///   - cpu: The CPU number to pin to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pin<D: ProcessDescriptor>(
        _ descriptor: borrowing D,
        to cpu: Int
    ) throws where D: ~Copyable {
        try setAffinity(CPUSet(cpu: cpu), for: descriptor)
    }

    /// Pins a process descriptor to a set of CPUs.
    ///
    /// - Parameters:
    ///   - descriptor: A process descriptor.
    ///   - cpus: The CPU numbers to allow.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pin<D: ProcessDescriptor>(
        _ descriptor: borrowing D,
        to cpus: [Int]
    ) throws where D: ~Copyable {
        try setAffinity(CPUSet(cpus: cpus), for: descriptor)
    }

    /// Gets the NUMA domain affinity for a process descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: A process descriptor.
    ///   - level: The level to query (default: which).
    /// - Returns: A tuple of the domain mask and policy.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getDomain<D: ProcessDescriptor>(
        for descriptor: borrowing D,
        level: Level = .which
    ) throws -> (domains: DomainSet, policy: DomainPolicy) where D: ~Copyable {
        try getDomain(level: level, for: .process(from: descriptor))
    }

    /// Sets the NUMA domain affinity for a process descriptor.
    ///
    /// - Parameters:
    ///   - domains: The domain mask.
    ///   - policy: The allocation policy.
    ///   - descriptor: A process descriptor.
    ///   - level: The level to set (default: which).
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func setDomain<D: ProcessDescriptor>(
        _ domains: DomainSet,
        policy: DomainPolicy,
        for descriptor: borrowing D,
        level: Level = .which
    ) throws where D: ~Copyable {
        try setDomain(domains, policy: policy, level: level, for: .process(from: descriptor))
    }
}
