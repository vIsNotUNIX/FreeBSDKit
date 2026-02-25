/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Glibc

// MARK: - Subject from Descriptors

extension Rctl.Subject {
    /// Creates a subject from a process descriptor.
    ///
    /// - Parameter descriptor: A process descriptor (from pdfork).
    /// - Returns: A subject targeting the process.
    /// - Throws: If the PID cannot be retrieved from the descriptor.
    ///
    /// Example:
    /// ```swift
    /// let result = try ProcessCapability.fork()
    /// if !result.isChild, let desc = result.descriptor {
    ///     let usage = try Rctl.getUsage(for: .process(from: desc))
    /// }
    /// ```
    public static func process<D: ProcessDescriptor>(
        from descriptor: borrowing D
    ) throws -> Rctl.Subject where D: ~Copyable {
        .process(try descriptor.pid())
    }
}

// MARK: - Convenience Methods with Descriptors

extension Rctl {
    /// Gets resource usage for a process descriptor.
    ///
    /// - Parameter descriptor: A process descriptor.
    /// - Returns: A dictionary of resource names to their current values.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getUsage<D: ProcessDescriptor>(
        for descriptor: borrowing D
    ) throws -> [String: String] where D: ~Copyable {
        try getUsage(for: .process(from: descriptor))
    }

    /// Gets resource usage for a specific resource from a process descriptor.
    ///
    /// - Parameters:
    ///   - resource: The resource to query.
    ///   - descriptor: A process descriptor.
    /// - Returns: The current value as a UInt64, or nil if not available.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getUsage<D: ProcessDescriptor>(
        of resource: Resource,
        for descriptor: borrowing D
    ) throws -> UInt64? where D: ~Copyable {
        try getUsage(of: resource, for: .process(from: descriptor))
    }

    /// Gets the rules applying to a process descriptor.
    ///
    /// - Parameter descriptor: A process descriptor.
    /// - Returns: An array of matching rules.
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func getRules<D: ProcessDescriptor>(
        for descriptor: borrowing D
    ) throws -> [Rule] where D: ~Copyable {
        try getRules(for: .process(from: descriptor))
    }

    /// Limits memory for a process descriptor.
    ///
    /// - Parameters:
    ///   - bytes: Maximum memory in bytes.
    ///   - descriptor: The process descriptor to limit.
    ///   - action: Action when limit is exceeded (default: deny).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitMemory<D: ProcessDescriptor>(
        _ bytes: UInt64,
        for descriptor: borrowing D,
        action: Action = .deny
    ) throws where D: ~Copyable {
        try limitMemory(bytes, for: .process(from: descriptor), action: action)
    }

    /// Limits CPU percentage for a process descriptor.
    ///
    /// - Parameters:
    ///   - percent: Maximum CPU percentage (0-100 per CPU).
    ///   - descriptor: The process descriptor to limit.
    ///   - action: Action when limit is exceeded (default: throttle).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitCPU<D: ProcessDescriptor>(
        _ percent: UInt64,
        for descriptor: borrowing D,
        action: Action = .throttle
    ) throws where D: ~Copyable {
        try limitCPU(percent, for: .process(from: descriptor), action: action)
    }

    /// Limits open files for a process descriptor.
    ///
    /// - Parameters:
    ///   - count: Maximum number of open files.
    ///   - descriptor: The process descriptor to limit.
    ///   - action: Action when limit is exceeded (default: deny).
    /// - Throws: `Rctl.Error` if the operation fails.
    public static func limitOpenFiles<D: ProcessDescriptor>(
        _ count: UInt64,
        for descriptor: borrowing D,
        action: Action = .deny
    ) throws where D: ~Copyable {
        try limitOpenFiles(count, for: .process(from: descriptor), action: action)
    }
}
