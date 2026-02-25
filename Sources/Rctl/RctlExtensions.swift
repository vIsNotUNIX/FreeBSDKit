/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CRctl
import Glibc

// MARK: - Convenience Methods

extension Rctl {
    /// Gets the resource usage for the current process.
    ///
    /// - Returns: A dictionary of resource names to their current values.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getCurrentProcessUsage() throws -> [String: String] {
        try getUsage(for: .process(getpid()))
    }

    /// Gets the resource usage for a specific resource.
    ///
    /// - Parameters:
    ///   - resource: The resource to query.
    ///   - subject: The subject to query.
    /// - Returns: The current value as a UInt64, or nil if not available.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getUsage(
        of resource: Resource,
        for subject: Subject
    ) throws -> UInt64? {
        let usage = try getUsage(for: subject)
        guard let valueStr = usage[resource.rawValue] else {
            return nil
        }
        return UInt64(valueStr)
    }

    /// Checks if rctl is enabled in the kernel.
    ///
    /// - Returns: `true` if rctl is enabled.
    public static var isEnabled: Bool {
        // Try a simple operation to see if rctl is available
        var outbuf = [CChar](repeating: 0, count: 256)
        let filter = ":"
        let result = filter.withCString { filterPtr in
            crctl_get_rules(filterPtr, 2, &outbuf, 256)
        }
        // ENOSYS means rctl is not enabled
        return result == 0 || Glibc.errno != ENOSYS
    }
}

// MARK: - Rule Builder

extension Rctl {
    /// A builder for creating rctl rules.
    public struct RuleBuilder {
        private var subject: Subject?
        private var resource: Resource?
        private var action: Action?
        private var amount: UInt64?
        private var per: Per?

        public init() {}

        /// Sets the subject for the rule.
        public mutating func forSubject(_ subject: Subject) -> RuleBuilder {
            self.subject = subject
            return self
        }

        /// Sets the resource to limit.
        public mutating func limiting(_ resource: Resource) -> RuleBuilder {
            self.resource = resource
            return self
        }

        /// Sets the action when the limit is exceeded.
        public mutating func withAction(_ action: Action) -> RuleBuilder {
            self.action = action
            return self
        }

        /// Sets the limit amount.
        public mutating func toAmount(_ amount: UInt64) -> RuleBuilder {
            self.amount = amount
            return self
        }

        /// Sets the per-unit for the limit.
        public mutating func per(_ per: Per) -> RuleBuilder {
            self.per = per
            return self
        }

        /// Builds the rule.
        ///
        /// - Returns: The constructed rule, or nil if required fields are missing.
        public func build() -> Rule? {
            guard let subject = subject,
                  let resource = resource,
                  let action = action,
                  let amount = amount else {
                return nil
            }
            return Rule(
                subject: subject,
                resource: resource,
                action: action,
                amount: amount,
                per: per
            )
        }
    }

    /// Creates a new rule builder.
    public static func ruleBuilder() -> RuleBuilder {
        RuleBuilder()
    }
}

// MARK: - Size Helpers

extension Rctl {
    /// Size constants for convenience.
    public enum Size {
        /// Kilobytes.
        public static func kb(_ n: UInt64) -> UInt64 { n * 1024 }

        /// Megabytes.
        public static func mb(_ n: UInt64) -> UInt64 { n * 1024 * 1024 }

        /// Gigabytes.
        public static func gb(_ n: UInt64) -> UInt64 { n * 1024 * 1024 * 1024 }
    }
}

// MARK: - Common Limits

extension Rctl {
    /// Adds a memory limit for a subject.
    ///
    /// - Parameters:
    ///   - bytes: Maximum memory in bytes.
    ///   - subject: The subject to limit.
    ///   - action: Action when limit is exceeded (default: deny).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitMemory(
        _ bytes: UInt64,
        for subject: Subject,
        action: Action = .deny
    ) throws {
        let rule = Rule(
            subject: subject,
            resource: .memoryUse,
            action: action,
            amount: bytes
        )
        try addRule(rule)
    }

    /// Adds a CPU percentage limit for a subject.
    ///
    /// - Parameters:
    ///   - percent: Maximum CPU percentage (0-100 per CPU).
    ///   - subject: The subject to limit.
    ///   - action: Action when limit is exceeded (default: throttle).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitCPU(
        _ percent: UInt64,
        for subject: Subject,
        action: Action = .throttle
    ) throws {
        let rule = Rule(
            subject: subject,
            resource: .pcpu,
            action: action,
            amount: percent
        )
        try addRule(rule)
    }

    /// Adds a process count limit for a subject.
    ///
    /// - Parameters:
    ///   - count: Maximum number of processes.
    ///   - subject: The subject to limit.
    ///   - action: Action when limit is exceeded (default: deny).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitProcesses(
        _ count: UInt64,
        for subject: Subject,
        action: Action = .deny
    ) throws {
        let rule = Rule(
            subject: subject,
            resource: .maxProc,
            action: action,
            amount: count
        )
        try addRule(rule)
    }

    /// Adds an open files limit for a subject.
    ///
    /// - Parameters:
    ///   - count: Maximum number of open files.
    ///   - subject: The subject to limit.
    ///   - action: Action when limit is exceeded (default: deny).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitOpenFiles(
        _ count: UInt64,
        for subject: Subject,
        action: Action = .deny
    ) throws {
        let rule = Rule(
            subject: subject,
            resource: .openFiles,
            action: action,
            amount: count
        )
        try addRule(rule)
    }
}
