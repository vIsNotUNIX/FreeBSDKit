/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Aggregation Functions

/// Adds a count aggregation.
///
/// Counts the number of times a probe fires, grouped by one or more keys.
///
/// ```swift
/// // Simple count by function name
/// Probe("syscall:::entry") {
///     Count(by: "probefunc")
/// }
///
/// // Named aggregation for later reference
/// Probe("syscall:::entry") {
///     Count(by: "probefunc", into: "syscalls")
/// }
///
/// // Multi-key aggregation
/// Probe("syscall:::entry") {
///     Count(by: ["execname", "probefunc"])
/// }
///
/// // Simple unnamed count
/// Probe("syscall:::entry") {
///     Count()
/// }
/// ```
public struct Count: Sendable {
    public let component: ProbeComponent

    /// Creates a count aggregation with a single key.
    ///
    /// - Parameters:
    ///   - key: The key expression (default: "probefunc").
    ///   - name: Optional aggregation name for referencing in Printa/Clear/Trunc.
    public init(by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = count();"))
    }

    /// Creates a count aggregation with multiple keys.
    ///
    /// - Parameters:
    ///   - keys: Array of key expressions.
    ///   - name: Optional aggregation name.
    public init(by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = count();"))
    }

    /// Creates a simple unnamed count (no keys).
    public init() {
        self.component = ProbeComponent(kind: .action("@ = count();"))
    }
}

extension Count: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a sum aggregation.
///
/// Sums a value expression, grouped by one or more keys.
///
/// ```swift
/// // Sum bytes read by process
/// Probe("syscall::read:return") {
///     When("arg0 > 0")
///     Sum("arg0", by: "execname")
/// }
///
/// // With multi-key and name
/// Probe("syscall::read:return") {
///     Sum("arg0", by: ["execname", "probefunc"], into: "bytes")
/// }
/// ```
public struct Sum: Sendable {
    public let component: ProbeComponent

    /// Creates a sum aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = sum(\(value));"))
    }

    /// Creates a sum aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = sum(\(value));"))
    }
}

extension Sum: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a min aggregation.
///
/// Tracks the minimum value seen, grouped by one or more keys.
public struct Min: Sendable {
    public let component: ProbeComponent

    /// Creates a min aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = min(\(value));"))
    }

    /// Creates a min aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = min(\(value));"))
    }
}

extension Min: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a max aggregation.
///
/// Tracks the maximum value seen, grouped by one or more keys.
public struct Max: Sendable {
    public let component: ProbeComponent

    /// Creates a max aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = max(\(value));"))
    }

    /// Creates a max aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = max(\(value));"))
    }
}

extension Max: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds an average aggregation.
///
/// Computes the average of values seen, grouped by one or more keys.
public struct Avg: Sendable {
    public let component: ProbeComponent

    /// Creates an average aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = avg(\(value));"))
    }

    /// Creates an average aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = avg(\(value));"))
    }
}

extension Avg: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a quantize (power-of-2 histogram) aggregation.
///
/// Creates a histogram with power-of-2 buckets, useful for visualizing
/// distributions of values like latencies or sizes.
///
/// ```swift
/// // Histogram of read sizes
/// Probe("syscall::read:return") {
///     Quantize("arg0", by: "execname")
/// }
///
/// // Named quantize for latency
/// Probe("syscall::read:return") {
///     Quantize("timestamp - self->ts", by: "execname", into: "latency")
/// }
/// ```
public struct Quantize: Sendable {
    public let component: ProbeComponent

    /// Creates a quantize aggregation with a single key.
    public init(_ value: String, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(key)] = quantize(\(value));"))
    }

    /// Creates a quantize aggregation with multiple keys.
    public init(_ value: String, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("@\(aggName)[\(keyList)] = quantize(\(value));"))
    }
}

extension Quantize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a linear quantize aggregation.
///
/// Creates a histogram with linear (evenly-spaced) buckets, useful when
/// you want consistent bucket sizes rather than power-of-2.
///
/// ```swift
/// // Histogram of read sizes from 0-1000 in steps of 100
/// Probe("syscall::read:return") {
///     Lquantize("arg0", low: 0, high: 1000, step: 100, by: "execname")
/// }
///
/// // Named for later reference
/// Probe("syscall::read:return") {
///     Lquantize("arg0", low: 0, high: 1000, step: 100, by: "execname", into: "sizes")
/// }
/// ```
public struct Lquantize: Sendable {
    public let component: ProbeComponent

    /// Creates a linear quantize aggregation with a single key.
    ///
    /// - Parameters:
    ///   - value: The value expression to histogram.
    ///   - low: The lower bound of the histogram.
    ///   - high: The upper bound of the histogram.
    ///   - step: The bucket size.
    ///   - key: The key expression (default: "probefunc").
    ///   - name: Optional aggregation name.
    public init(_ value: String, low: Int, high: Int, step: Int, by key: String = "probefunc", into name: String? = nil) {
        let aggName = name ?? ""
        self.component = ProbeComponent(
            kind: .action("@\(aggName)[\(key)] = lquantize(\(value), \(low), \(high), \(step));")
        )
    }

    /// Creates a linear quantize aggregation with multiple keys.
    public init(_ value: String, low: Int, high: Int, step: Int, by keys: [String], into name: String? = nil) {
        let aggName = name ?? ""
        let keyList = keys.joined(separator: ", ")
        self.component = ProbeComponent(
            kind: .action("@\(aggName)[\(keyList)] = lquantize(\(value), \(low), \(high), \(step));")
        )
    }
}

extension Lquantize: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
