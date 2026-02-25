/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCpuset
import Glibc

// MARK: - Convenience Methods

extension Cpuset {
    /// Gets the number of CPUs available to the current process.
    ///
    /// - Returns: The number of CPUs.
    public static func availableCPUCount() throws -> Int {
        let mask = try getAffinity(level: .cpuset, for: .currentProcess)
        return mask.count
    }

    /// Gets all CPUs available to the current process.
    ///
    /// - Returns: Array of CPU numbers.
    public static func availableCPUs() throws -> [Int] {
        let mask = try getAffinity(level: .cpuset, for: .currentProcess)
        return mask.cpus
    }

    /// Gets the root (system-wide) CPU set.
    ///
    /// - Returns: The CPU set containing all system CPUs.
    public static func rootCPUs() throws -> CPUSet {
        try getAffinity(level: .root, for: .currentThread)
    }

    /// Pins the current thread to a single CPU.
    ///
    /// - Parameter cpu: The CPU number to pin to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pinCurrentThread(to cpu: Int) throws {
        try setAffinity(CPUSet(cpu: cpu), for: .currentThread)
    }

    /// Pins the current process to a single CPU.
    ///
    /// - Parameter cpu: The CPU number to pin to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pinCurrentProcess(to cpu: Int) throws {
        try setAffinity(CPUSet(cpu: cpu), for: .currentProcess)
    }

    /// Pins the current thread to a set of CPUs.
    ///
    /// - Parameter cpus: The CPU numbers to allow.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pinCurrentThread(to cpus: [Int]) throws {
        try setAffinity(CPUSet(cpus: cpus), for: .currentThread)
    }

    /// Pins the current process to a set of CPUs.
    ///
    /// - Parameter cpus: The CPU numbers to allow.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func pinCurrentProcess(to cpus: [Int]) throws {
        try setAffinity(CPUSet(cpus: cpus), for: .currentProcess)
    }

    /// Resets the current thread's affinity to all available CPUs.
    ///
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func resetCurrentThreadAffinity() throws {
        let available = try getAffinity(level: .cpuset, for: .currentThread)
        try setAffinity(available, for: .currentThread)
    }

    /// Resets the current process's affinity to all available CPUs.
    ///
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func resetCurrentProcessAffinity() throws {
        let available = try getAffinity(level: .cpuset, for: .currentProcess)
        try setAffinity(available, for: .currentProcess)
    }
}

// MARK: - NUMA Convenience

extension Cpuset {
    /// Gets the number of NUMA domains on the system.
    ///
    /// This queries the root domain set to find all available domains.
    ///
    /// - Returns: The number of NUMA domains.
    public static func domainCount() throws -> Int {
        let (domains, _) = try getDomain(level: .root, for: .currentThread)
        return domains.count
    }

    /// Sets the current thread to prefer a specific NUMA domain.
    ///
    /// - Parameter domain: The domain number to prefer.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func preferDomain(_ domain: Int) throws {
        try setDomain(
            DomainSet(domain: domain),
            policy: .prefer,
            for: .currentThread
        )
    }

    /// Sets the current thread to use first-touch allocation.
    ///
    /// Memory will be allocated on the domain local to the running CPU.
    ///
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func useFirstTouchAllocation() throws {
        var domains = DomainSet()
        domains.fill()
        try setDomain(domains, policy: .firstTouch, for: .currentThread)
    }

    /// Sets the current thread to use round-robin allocation.
    ///
    /// Memory will be spread across all available domains.
    ///
    /// - Parameter domains: Optional specific domains to use.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func useRoundRobinAllocation(domains: [Int]? = nil) throws {
        let domainSet: DomainSet
        if let specific = domains {
            domainSet = DomainSet(domains: specific)
        } else {
            var ds = DomainSet()
            ds.fill()
            domainSet = ds
        }
        try setDomain(domainSet, policy: .roundRobin, for: .currentThread)
    }

    /// Sets the current thread to interleave memory across domains.
    ///
    /// - Parameter domains: Optional specific domains to interleave across.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func useInterleaveAllocation(domains: [Int]? = nil) throws {
        let domainSet: DomainSet
        if let specific = domains {
            domainSet = DomainSet(domains: specific)
        } else {
            var ds = DomainSet()
            ds.fill()
            domainSet = ds
        }
        try setDomain(domainSet, policy: .interleave, for: .currentThread)
    }
}

// MARK: - IRQ Affinity

extension Cpuset {
    /// Gets the CPU affinity for an IRQ.
    ///
    /// - Parameter irq: The IRQ number.
    /// - Returns: The CPU set the IRQ is bound to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getIRQAffinity(_ irq: Int32) throws -> CPUSet {
        try getAffinity(for: .irq(irq))
    }

    /// Sets the CPU affinity for an IRQ.
    ///
    /// - Parameters:
    ///   - irq: The IRQ number.
    ///   - cpus: The CPU set to bind the IRQ to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    /// - Note: Requires root privileges.
    public static func setIRQAffinity(_ irq: Int32, to cpus: CPUSet) throws {
        try setAffinity(cpus, for: .irq(irq))
    }
}

// MARK: - Jail Affinity

extension Cpuset {
    /// Gets the CPU affinity for a jail.
    ///
    /// - Parameter jid: The jail ID.
    /// - Returns: The CPU set the jail is restricted to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    public static func getJailAffinity(_ jid: Int32) throws -> CPUSet {
        try getAffinity(for: .jail(jid))
    }

    /// Sets the CPU affinity for a jail.
    ///
    /// - Parameters:
    ///   - jid: The jail ID.
    ///   - cpus: The CPU set to restrict the jail to.
    /// - Throws: `Cpuset.Error` if the operation fails.
    /// - Note: Requires root privileges.
    public static func setJailAffinity(_ jid: Int32, to cpus: CPUSet) throws {
        try setAffinity(cpus, for: .jail(jid))
    }
}
