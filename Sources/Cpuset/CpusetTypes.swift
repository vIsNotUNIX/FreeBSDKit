/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCpuset
import Glibc

// MARK: - CPUSet

/// A bitmask representing a set of CPUs.
public struct CPUSet: Sendable, Equatable {
    /// The underlying cpuset_t value.
    internal var rawValue: cpuset_t

    /// The maximum number of CPUs supported.
    public static var maxSize: Int { Int(CCPUSET_SETSIZE) }

    /// Creates an empty CPU set.
    public init() {
        rawValue = cpuset_t()
        ccpuset_zero(&rawValue)
    }

    /// Creates a CPU set from a raw cpuset_t.
    internal init(_ raw: cpuset_t) {
        self.rawValue = raw
    }

    /// Creates a CPU set containing specific CPUs.
    ///
    /// - Parameter cpus: The CPU numbers to include.
    public init(cpus: [Int]) {
        rawValue = cpuset_t()
        ccpuset_zero(&rawValue)
        for cpu in cpus {
            ccpuset_set(Int32(cpu), &rawValue)
        }
    }

    /// Creates a CPU set containing a single CPU.
    ///
    /// - Parameter cpu: The CPU number.
    public init(cpu: Int) {
        rawValue = cpuset_t()
        ccpuset_zero(&rawValue)
        ccpuset_set(Int32(cpu), &rawValue)
    }

    /// Creates a CPU set containing a range of CPUs.
    ///
    /// - Parameter range: The range of CPU numbers.
    public init(range: Range<Int>) {
        rawValue = cpuset_t()
        ccpuset_zero(&rawValue)
        for cpu in range {
            ccpuset_set(Int32(cpu), &rawValue)
        }
    }

    /// Sets a CPU in the mask.
    ///
    /// - Parameter cpu: The CPU number to set.
    public mutating func set(cpu: Int) {
        ccpuset_set(Int32(cpu), &rawValue)
    }

    /// Clears a CPU from the mask.
    ///
    /// - Parameter cpu: The CPU number to clear.
    public mutating func clear(cpu: Int) {
        ccpuset_clr(Int32(cpu), &rawValue)
    }

    /// Checks if a CPU is set in the mask.
    ///
    /// - Parameter cpu: The CPU number to check.
    /// - Returns: `true` if the CPU is set.
    public func isSet(cpu: Int) -> Bool {
        var copy = rawValue
        return ccpuset_isset(Int32(cpu), &copy) != 0
    }

    /// Clears all CPUs from the mask.
    public mutating func clear() {
        ccpuset_zero(&rawValue)
    }

    /// Sets all CPUs in the mask.
    public mutating func fill() {
        ccpuset_fill(&rawValue)
    }

    /// The number of CPUs set in the mask.
    public var count: Int {
        var copy = rawValue
        return Int(ccpuset_count(&copy))
    }

    /// Whether the mask is empty.
    public var isEmpty: Bool {
        var copy = rawValue
        return ccpuset_empty(&copy) != 0
    }

    /// Whether all CPUs are set.
    public var isFull: Bool {
        var copy = rawValue
        return ccpuset_isfullset(&copy) != 0
    }

    /// Returns the list of CPU numbers that are set.
    public var cpus: [Int] {
        var result: [Int] = []
        for cpu in 0..<CPUSet.maxSize {
            if isSet(cpu: cpu) {
                result.append(cpu)
            }
        }
        return result
    }

    /// The first set CPU, or nil if empty.
    public var first: Int? {
        var copy = rawValue
        let ffs = ccpuset_ffs(&copy)
        return ffs > 0 ? Int(ffs - 1) : nil
    }

    /// The last set CPU, or nil if empty.
    public var last: Int? {
        var copy = rawValue
        let fls = ccpuset_fls(&copy)
        return fls > 0 ? Int(fls - 1) : nil
    }

    // MARK: - Set Operations

    /// Returns the union of two CPU sets.
    public func union(_ other: CPUSet) -> CPUSet {
        var result = cpuset_t()
        var a = self.rawValue
        var b = other.rawValue
        ccpuset_or(&result, &a, &b)
        return CPUSet(result)
    }

    /// Returns the intersection of two CPU sets.
    public func intersection(_ other: CPUSet) -> CPUSet {
        var result = cpuset_t()
        var a = self.rawValue
        var b = other.rawValue
        ccpuset_and(&result, &a, &b)
        return CPUSet(result)
    }

    /// Returns this set minus the other set.
    public func subtracting(_ other: CPUSet) -> CPUSet {
        var result = cpuset_t()
        var a = self.rawValue
        var b = other.rawValue
        ccpuset_andnot(&result, &a, &b)
        return CPUSet(result)
    }

    public static func == (lhs: CPUSet, rhs: CPUSet) -> Bool {
        var a = lhs.rawValue
        var b = rhs.rawValue
        return ccpuset_equal(&a, &b) != 0
    }
}

extension CPUSet: CustomStringConvertible {
    public var description: String {
        if isEmpty {
            return "CPUSet(empty)"
        }
        return "CPUSet(\(cpus.map(String.init).joined(separator: ", ")))"
    }
}

// MARK: - DomainSet

/// A bitmask representing a set of NUMA memory domains.
public struct DomainSet: Sendable, Equatable {
    /// The underlying domainset_t value.
    internal var rawValue: domainset_t

    /// Creates an empty domain set.
    public init() {
        rawValue = domainset_t()
        cdomainset_zero(&rawValue)
    }

    /// Creates a domain set from a raw domainset_t.
    internal init(_ raw: domainset_t) {
        self.rawValue = raw
    }

    /// Creates a domain set containing specific domains.
    ///
    /// - Parameter domains: The domain numbers to include.
    public init(domains: [Int]) {
        rawValue = domainset_t()
        cdomainset_zero(&rawValue)
        for domain in domains {
            cdomainset_set(Int32(domain), &rawValue)
        }
    }

    /// Creates a domain set containing a single domain.
    ///
    /// - Parameter domain: The domain number.
    public init(domain: Int) {
        rawValue = domainset_t()
        cdomainset_zero(&rawValue)
        cdomainset_set(Int32(domain), &rawValue)
    }

    /// Sets a domain in the mask.
    public mutating func set(domain: Int) {
        cdomainset_set(Int32(domain), &rawValue)
    }

    /// Clears a domain from the mask.
    public mutating func clear(domain: Int) {
        cdomainset_clr(Int32(domain), &rawValue)
    }

    /// Checks if a domain is set in the mask.
    public func isSet(domain: Int) -> Bool {
        var copy = rawValue
        return cdomainset_isset(Int32(domain), &copy) != 0
    }

    /// Clears all domains from the mask.
    public mutating func clear() {
        cdomainset_zero(&rawValue)
    }

    /// Sets all domains in the mask.
    public mutating func fill() {
        cdomainset_fill(&rawValue)
    }

    /// The number of domains set in the mask.
    public var count: Int {
        var copy = rawValue
        return Int(cdomainset_count(&copy))
    }

    /// Whether the mask is empty.
    public var isEmpty: Bool {
        var copy = rawValue
        return cdomainset_empty(&copy) != 0
    }

    public static func == (lhs: DomainSet, rhs: DomainSet) -> Bool {
        // Compare bit-by-bit since domainset doesn't have equal macro
        var a = lhs.rawValue
        var b = rhs.rawValue
        return memcmp(&a, &b, MemoryLayout<domainset_t>.size) == 0
    }
}

// MARK: - DomainPolicy

/// NUMA memory allocation policy.
public enum DomainPolicy: Int32, Sendable {
    /// Allocate memory round-robin across domains.
    case roundRobin = 1  // DOMAINSET_POLICY_ROUNDROBIN

    /// Allocate from the domain local to the running CPU.
    case firstTouch = 2  // DOMAINSET_POLICY_FIRSTTOUCH

    /// Prefer a specific domain, fall back to round-robin.
    case prefer = 3  // DOMAINSET_POLICY_PREFER

    /// Interleave allocations across domains.
    case interleave = 4  // DOMAINSET_POLICY_INTERLEAVE
}

// MARK: - Level

extension Cpuset {
    /// The level at which to query or set affinity.
    public enum Level: Int32, Sendable {
        /// Root set - all system CPUs.
        case root = 1  // CPU_LEVEL_ROOT

        /// Available CPUs for the target's cpuset.
        case cpuset = 2  // CPU_LEVEL_CPUSET

        /// Actual mask for the specific target.
        case which = 3  // CPU_LEVEL_WHICH
    }
}

// MARK: - Which

extension Cpuset {
    /// Specifies how to interpret the target ID.
    public enum Which: Int32, Sendable {
        /// Thread ID.
        case thread = 1  // CPU_WHICH_TID

        /// Process ID.
        case process = 2  // CPU_WHICH_PID

        /// Cpuset ID.
        case cpuset = 3  // CPU_WHICH_CPUSET

        /// IRQ number.
        case irq = 4  // CPU_WHICH_IRQ

        /// Jail ID.
        case jail = 5  // CPU_WHICH_JAIL

        /// NUMA domain ID.
        case domain = 6  // CPU_WHICH_DOMAIN

        /// IRQ handler (not ithread).
        case intrHandler = 7  // CPU_WHICH_INTRHANDLER

        /// IRQ's ithread.
        case ithread = 8  // CPU_WHICH_ITHREAD

        /// Process or thread ID (auto-detect).
        case tidpid = 9  // CPU_WHICH_TIDPID
    }
}

// MARK: - Target

extension Cpuset {
    /// A target for cpuset operations.
    public struct Target: Sendable {
        /// How to interpret the ID.
        public let which: Which

        /// The target ID.
        public let id: id_t

        /// Creates a target.
        public init(which: Which, id: id_t) {
            self.which = which
            self.id = id
        }

        /// The current thread.
        public static let currentThread = Target(which: .thread, id: -1)

        /// The current process.
        public static let currentProcess = Target(which: .process, id: 0)

        /// A specific thread.
        public static func thread(_ tid: pid_t) -> Target {
            Target(which: .thread, id: id_t(tid))
        }

        /// A specific process.
        public static func process(_ pid: pid_t) -> Target {
            Target(which: .process, id: id_t(pid))
        }

        /// A specific cpuset.
        public static func cpuset(_ setId: CpusetID) -> Target {
            Target(which: .cpuset, id: id_t(setId.rawValue))
        }

        /// A specific IRQ.
        public static func irq(_ irqNum: Int32) -> Target {
            Target(which: .irq, id: id_t(irqNum))
        }

        /// A specific jail.
        public static func jail(_ jid: Int32) -> Target {
            Target(which: .jail, id: id_t(jid))
        }

        /// A specific NUMA domain.
        public static func domain(_ domainId: Int32) -> Target {
            Target(which: .domain, id: id_t(domainId))
        }
    }
}

// MARK: - CpusetID

extension Cpuset {
    /// An identifier for a named cpuset.
    public struct CpusetID: Sendable, Equatable, Hashable {
        /// The raw cpusetid_t value.
        public let rawValue: cpusetid_t

        /// Creates a cpuset ID from a raw value.
        public init(_ value: cpusetid_t) {
            self.rawValue = value
        }

        /// The default (root) cpuset.
        public static let `default` = CpusetID(CCPUSET_DEFAULT)

        /// An invalid cpuset ID.
        public static let invalid = CpusetID(CCPUSET_INVALID)

        /// Whether this is a valid cpuset ID.
        public var isValid: Bool {
            rawValue != CCPUSET_INVALID
        }
    }
}

extension Cpuset.CpusetID: CustomStringConvertible {
    public var description: String {
        if rawValue == CCPUSET_INVALID {
            return "CpusetID(invalid)"
        }
        return "CpusetID(\(rawValue))"
    }
}
