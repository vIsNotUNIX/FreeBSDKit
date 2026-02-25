/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CRctl
import Glibc

/// Swift interface to FreeBSD's rctl(4) resource control subsystem.
///
/// The rctl subsystem provides a flexible resource limits mechanism for
/// processes, users, login classes, and jails. Rules can be added or
/// removed at runtime.
///
/// ## Usage
///
/// ```swift
/// // Get current resource usage for a process
/// let usage = try Rctl.getUsage(for: .process(getpid()))
/// print("CPU time: \(usage["cputime"] ?? "unknown")")
///
/// // Add a rule to limit memory for a jail
/// let rule = Rctl.Rule(
///     subject: .jail("myjail"),
///     resource: .memoryUse,
///     action: .deny,
///     amount: 1024 * 1024 * 512  // 512MB
/// )
/// try Rctl.addRule(rule)
///
/// // Get all rules for a user
/// let rules = try Rctl.getRules(for: .user("www"))
///
/// // Remove a rule
/// try Rctl.removeRule(rule)
/// ```
///
/// - Note: The rctl subsystem must be enabled in the kernel. Check with
///   `sysctl kern.racct.enable`.
public enum Rctl {
    /// Buffer size for rctl operations.
    private static let bufferSize = 4096

    // MARK: - Get Resource Usage

    /// Gets the current resource usage for a subject.
    ///
    /// - Parameter subject: The subject to query.
    /// - Returns: A dictionary of resource names to their current values.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getUsage(for subject: Subject) throws -> [String: String] {
        let filter = subject.filterString
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = filter.withCString { filterPtr in
            crctl_get_racct(filterPtr, filter.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return parseKeyValuePairs(String(cString: outbuf))
    }

    // MARK: - Get Rules

    /// Gets all rules matching a filter.
    ///
    /// - Parameter subject: Optional subject filter. If nil, returns all rules.
    /// - Returns: An array of matching rules.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getRules(for subject: Subject? = nil) throws -> [Rule] {
        let filter = subject?.filterString ?? ":"
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = filter.withCString { filterPtr in
            crctl_get_rules(filterPtr, filter.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        let output = String(cString: outbuf)
        return parseRules(output)
    }

    /// Gets the resource limits for a subject.
    ///
    /// - Parameter subject: The subject to query.
    /// - Returns: A dictionary of resource names to their limits.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getLimits(for subject: Subject) throws -> [String: String] {
        let filter = subject.filterString
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = filter.withCString { filterPtr in
            crctl_get_limits(filterPtr, filter.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }

        return parseKeyValuePairs(String(cString: outbuf))
    }

    // MARK: - Add/Remove Rules

    /// Adds a resource control rule.
    ///
    /// - Parameter rule: The rule to add.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func addRule(_ rule: Rule) throws {
        let ruleStr = rule.ruleString
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = ruleStr.withCString { rulePtr in
            crctl_add_rule(rulePtr, ruleStr.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes resource control rules matching the filter.
    ///
    /// - Parameter rule: The rule to remove (used as a filter).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func removeRule(_ rule: Rule) throws {
        let ruleStr = rule.ruleString
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = ruleStr.withCString { rulePtr in
            crctl_remove_rule(rulePtr, ruleStr.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Removes all rules matching a subject filter.
    ///
    /// - Parameter subject: The subject whose rules should be removed.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func removeRules(for subject: Subject) throws {
        let filter = subject.filterString + ":::"
        var outbuf = [CChar](repeating: 0, count: bufferSize)

        let result = filter.withCString { filterPtr in
            crctl_remove_rule(filterPtr, filter.utf8.count + 1, &outbuf, bufferSize)
        }

        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    // MARK: - Parsing Helpers

    private static func parseKeyValuePairs(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = output.split(separator: ",")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                result[String(kv[0])] = String(kv[1])
            }
        }
        return result
    }

    private static func parseRules(_ output: String) -> [Rule] {
        var rules: [Rule] = []
        let lines = output.split(separator: ",")
        for line in lines {
            if let rule = Rule(parsing: String(line)) {
                rules.append(rule)
            }
        }
        return rules
    }
}
