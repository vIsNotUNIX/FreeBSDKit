/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// A builder for creating D scripts with a fluent API.
///
/// `DTraceScript` provides a Swift-native way to construct D programs
/// without writing raw D syntax.
///
/// ## Examples
///
/// ```swift
/// // Simple syscall tracing
/// let script = DTraceScript("syscall:::entry")
///     .targeting(.execname("nginx"))
///     .count(by: "probefunc")
///
/// // Multiple probes
/// let script = DTraceScript("syscall::open:entry")
///     .action("self->ts = timestamp;")
///     .probe("syscall::open:return")
///     .action("@[execname] = quantize(timestamp - self->ts);")
///
/// // Get the generated D code
/// print(script.build())
/// ```
public struct DTraceScript: Sendable {
    private var clauses: [Clause] = []
    private var currentProbe: String?
    private var currentTarget: DTraceTarget = .all
    private var currentAction: String = ""

    private struct Clause: Sendable {
        let probe: String
        let target: DTraceTarget
        let action: String

        func render() -> String {
            var result = probe
            if !target.predicate.isEmpty {
                result += "\n/\(target.predicate)/"
            }
            result += "\n{\n"
            if !action.isEmpty {
                let indented = action.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "    \($0)" }
                    .joined(separator: "\n")
                result += indented + "\n"
            }
            result += "}"
            return result
        }
    }

    // MARK: - Initialization

    /// Creates an empty script.
    public init() {}

    /// Creates a script starting with a probe specification.
    public init(_ probeSpec: String) {
        self.currentProbe = probeSpec
    }

    // MARK: - Building

    /// Adds a new probe clause to the script.
    public func probe(_ spec: String) -> DTraceScript {
        var copy = finalizeCurrentClause()
        copy.currentProbe = spec
        copy.currentTarget = .all
        copy.currentAction = ""
        return copy
    }

    /// Sets the target filter for the current probe.
    public func targeting(_ target: DTraceTarget) -> DTraceScript {
        var copy = self
        copy.currentTarget = target
        return copy
    }

    /// Sets the action for the current probe.
    public func action(_ code: String) -> DTraceScript {
        var copy = self
        copy.currentAction = code
        return copy
    }

    /// Adds a predicate condition to the current probe.
    public func when(_ predicate: String) -> DTraceScript {
        var copy = self
        copy.currentTarget = copy.currentTarget.and(.custom(predicate))
        return copy
    }

    // MARK: - Common Actions

    /// Adds a printf action.
    public func printf(_ format: String, _ args: String...) -> DTraceScript {
        let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
        return action("printf(\"\(format)\\n\"\(argList));")
    }

    /// Adds a count aggregation.
    public func count(by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = count();")
    }

    /// Adds a sum aggregation.
    public func sum(_ value: String, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = sum(\(value));")
    }

    /// Adds a quantize (histogram) aggregation.
    public func quantize(_ value: String, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = quantize(\(value));")
    }

    /// Adds a linear quantize aggregation.
    public func lquantize(_ value: String, low: Int, high: Int, step: Int, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = lquantize(\(value), \(low), \(high), \(step));")
    }

    /// Adds a min aggregation.
    public func min(_ value: String, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = min(\(value));")
    }

    /// Adds a max aggregation.
    public func max(_ value: String, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = max(\(value));")
    }

    /// Adds an avg aggregation.
    public func avg(_ value: String, by key: String = "probefunc") -> DTraceScript {
        return action("@[\(key)] = avg(\(value));")
    }

    /// Adds a stack trace action.
    public func stack(userland: Bool = false) -> DTraceScript {
        return action(userland ? "ustack();" : "stack();")
    }

    /// Traces the value (prints it).
    public func trace(_ value: String) -> DTraceScript {
        return action("trace(\(value));")
    }

    // MARK: - Output

    /// Finalizes and returns the D script as a string.
    public func build() -> String {
        let final = finalizeCurrentClause()
        return final.clauses.map { $0.render() }.joined(separator: "\n\n")
    }

    private func finalizeCurrentClause() -> DTraceScript {
        var copy = self
        if let probe = currentProbe {
            copy.clauses.append(Clause(
                probe: probe,
                target: currentTarget,
                action: currentAction
            ))
            copy.currentProbe = nil
        }
        return copy
    }
}

extension DTraceScript: CustomStringConvertible {
    public var description: String {
        build()
    }
}

// MARK: - Predefined Scripts

extension DTraceScript {
    /// Counts syscalls by function name.
    ///
    /// Uses `syscall:freebsd:` to avoid Linux compatibility layer probes.
    public static func syscallCounts(for target: DTraceTarget = .all) -> DTraceScript {
        DTraceScript("syscall:freebsd::entry")
            .targeting(target)
            .count(by: "probefunc")
    }

    /// Traces file opens.
    public static func fileOpens(for target: DTraceTarget = .all) -> DTraceScript {
        DTraceScript("syscall:freebsd:open*:entry")
            .targeting(target)
            .printf("%s: %s", "execname", "copyinstr(arg0)")
    }

    /// Profiles CPU usage.
    public static func cpuProfile(hz: Int = 997, for target: DTraceTarget = .all) -> DTraceScript {
        DTraceScript("profile-\(hz)")
            .targeting(target)
            .count(by: "execname")
    }

    /// Traces process execution.
    public static func processExec() -> DTraceScript {
        DTraceScript("proc:::exec-success")
            .printf("%s[%d] exec'd %s", "execname", "pid", "curpsinfo->pr_psargs")
    }

    /// Traces read/write syscalls with byte counts.
    public static func ioBytes(for target: DTraceTarget = .all) -> DTraceScript {
        DTraceScript("syscall:freebsd:read:return")
            .targeting(target)
            .when("arg0 > 0")
            .sum("arg0", by: "execname")
            .probe("syscall:freebsd:write:return")
            .targeting(target)
            .when("arg0 > 0")
            .sum("arg0", by: "execname")
    }

    /// Times syscall latency.
    public static func syscallLatency(_ syscall: String, for target: DTraceTarget = .all) -> DTraceScript {
        DTraceScript("syscall:freebsd:\(syscall):entry")
            .targeting(target)
            .action("self->ts = timestamp;")
            .probe("syscall:freebsd:\(syscall):return")
            .targeting(target)
            .when("self->ts")
            .action("@[execname] = quantize(timestamp - self->ts); self->ts = 0;")
    }
}
