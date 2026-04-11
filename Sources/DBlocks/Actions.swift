/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Output Actions

/// Adds a printf action.
///
/// Prints formatted output when the probe fires.
///
/// ```swift
/// Probe("syscall::open:entry") {
///     Printf("%s[%d]: %s", "execname", "pid", "copyinstr(arg0)")
/// }
/// ```
public struct Printf: Sendable {
    public let component: ProbeComponent

    public init(_ format: String, _ args: String...) {
        let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("printf(\"\(format)\\n\"\(argList));"))
    }
}

extension Printf: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a trace action.
///
/// Traces a single value to the output buffer.
///
/// ```swift
/// Probe("syscall::read:return") {
///     Trace("arg0")
/// }
/// ```
public struct Trace: Sendable {
    public let component: ProbeComponent

    public init(_ value: String) {
        self.component = ProbeComponent(kind: .action("trace(\(value));"))
    }
}

extension Trace: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a stack trace action.
///
/// Captures a kernel or userland stack trace.
///
/// ```swift
/// Probe("fbt::malloc:entry") {
///     Stack()                    // Kernel stack
///     Stack(userland: true)      // User stack
/// }
/// ```
public struct Stack: Sendable {
    public let component: ProbeComponent

    public init(userland: Bool = false) {
        self.component = ProbeComponent(kind: .action(userland ? "ustack();" : "stack();"))
    }
}

extension Stack: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a raw D action.
///
/// Use this for actions not covered by the built-in helpers.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Action("self->ts = timestamp;")
/// }
/// Probe("syscall::read:return") {
///     When("self->ts")
///     Action("@[execname] = quantize(timestamp - self->ts);")
///     Action("self->ts = 0;")
/// }
/// ```
public struct Action: Sendable {
    public let component: ProbeComponent

    public init(_ code: String) {
        self.component = ProbeComponent(kind: .action(code))
    }
}

extension Action: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Timestamp and Latency Helpers

/// Adds a self-clearing timestamp pattern for latency measurement.
///
/// Use this at entry points to record the start time.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Timestamp()  // self->ts = timestamp;
/// }
/// ```
public struct Timestamp: Sendable {
    public let component: ProbeComponent
    public let variable: String

    public init(_ variable: String = "self->ts") {
        self.variable = variable
        self.component = ProbeComponent(kind: .action("\(variable) = timestamp;"))
    }
}

extension Timestamp: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Adds a latency calculation action.
///
/// Use this at return points to calculate and aggregate latency.
/// Pairs with `Timestamp` at entry points.
///
/// ```swift
/// Probe("syscall::read:entry") {
///     Timestamp()
/// }
/// Probe("syscall::read:return") {
///     When("self->ts")
///     Latency(by: "execname")
/// }
/// ```
public struct Latency: Sendable {
    public let component: ProbeComponent

    public init(variable: String = "self->ts", by key: String = "execname") {
        self.component = ProbeComponent(
            kind: .action("@[\(key)] = quantize(timestamp - \(variable)); \(variable) = 0;")
        )
    }
}

extension Latency: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Memory Tracing

/// Traces a region of memory to the trace buffer.
///
/// `tracemem(addr, size)` copies `size` bytes from `addr` (in the kernel
/// or current process address space) into the trace buffer, where it can
/// be inspected with `dtrace -x bufpolicy=fill`. Pair with `Copyin` if
/// you need to capture user memory through a kernel pointer first.
///
/// ```swift
/// Probe("syscall::write:entry") {
///     Tracemem("arg1", size: 64)
/// }
/// ```
public struct Tracemem: Sendable {
    public let component: ProbeComponent

    /// - Parameters:
    ///   - address: D expression evaluating to the source address.
    ///   - size: Number of bytes to copy.
    public init(_ address: String, size: Int) {
        self.component = ProbeComponent(kind: .action("tracemem(\(address), \(size));"))
    }

    /// Three-argument `tracemem(addr, dsize, esize)` form.
    ///
    /// `dsize` is the *maximum* number of bytes to copy (a constant
    /// known at script-compile time, i.e. the static buffer size),
    /// and `esize` is the *runtime* expression that says how many of
    /// those bytes are actually meaningful for this probe firing.
    /// The trace consumer sees only the first `esize` bytes; the
    /// remainder are zero-padded out to `dsize`. Use this when the
    /// length of the data lives in another argument or a thread-
    /// local variable.
    ///
    /// ```swift
    /// // Trace up to 1024 bytes of arg1, but only the leading
    /// // arg2 bytes are real data.
    /// Tracemem("arg1", maxSize: 1024, length: "arg2")
    /// ```
    ///
    /// - Parameters:
    ///   - address: D expression evaluating to the source address.
    ///   - maxSize: Maximum bytes to copy (compile-time constant).
    ///   - length: Runtime expression giving the number of valid bytes.
    public init(_ address: String, maxSize: Int, length: String) {
        self.component = ProbeComponent(
            kind: .action("tracemem(\(address), \(maxSize), \(length));")
        )
    }
}

extension Tracemem: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Copies a region of user memory into a clause-local scratch buffer.
///
/// `copyin(addr, size)` returns a kernel-side copy of the user buffer.
/// Pair with `Tracemem` to record the bytes, or assign into a thread-
/// local variable for later inspection.
///
/// ```swift
/// Probe("syscall::write:entry") {
///     Tracemem("(uintptr_t)copyin(arg1, 64)", size: 64)
/// }
/// ```
public struct Copyin: Sendable {
    public let component: ProbeComponent

    /// Copy `size` bytes from a user address into a thread-local
    /// variable, addressable from later actions in the same probe or
    /// from a paired return-probe.
    ///
    /// - Parameters:
    ///   - address: D expression evaluating to a user-space address.
    ///   - size: Number of bytes to copy.
    ///   - destination: Thread- or clause-local variable to receive the
    ///     copy.
    public init(from address: String, size: Int, into destination: Var) {
        self.component = ProbeComponent(
            kind: .action("\(destination.expression) = copyin(\(address), \(size));")
        )
    }
}

extension Copyin: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Copies user memory directly into an existing destination buffer.
///
/// `copyinto(uaddr, size, kaddr)` copies from a user-space address into
/// a kernel buffer the script already controls (e.g. a slot in a
/// thread-local that was sized via `alloca()`). Use this when you need
/// the data in a known location rather than the scratch buffer
/// `copyin` returns.
///
/// ```swift
/// Probe("syscall::write:entry") {
///     // Pre-allocate 64-byte slot in self->buf, then fill it.
///     Action("self->buf = (char *)alloca(64);")
///     Copyinto(from: "arg1", size: 64, into: "self->buf")
/// }
/// ```
public struct Copyinto: Sendable {
    public let component: ProbeComponent

    /// - Parameters:
    ///   - address: D expression evaluating to a user-space address.
    ///   - size: Number of bytes to copy.
    ///   - destination: Pre-allocated kernel-side destination buffer.
    public init(from address: String, size: Int, into destination: String) {
        self.component = ProbeComponent(
            kind: .action("copyinto(\(address), \(size), \(destination));")
        )
    }
}

extension Copyinto: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Buffer Control

/// Discards trace data accumulated by the current probe firing.
///
/// `discard()` is the cheap way to suppress output for a probe that
/// fired but isn't interesting after all — typically used inside a
/// predicate-driven branch to keep buffer pressure down. Compare with
/// `Stop`, which stops *all* tracing process-wide.
///
/// ```swift
/// Probe("syscall:::entry") {
///     When("pid == $target")
///     Action("/* … record interesting fields … */")
///     When("self->boring")
///     Discard()
/// }
/// ```
public struct Discard: Sendable {
    public let component: ProbeComponent

    public init() {
        self.component = ProbeComponent(kind: .action("discard();"))
    }
}

extension Discard: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Re-points the script's trace output to a new file.
///
/// `freopen(format, args…)` closes the current output and opens a new
/// one at the path produced by the format string. Pass an empty string
/// to revert to the original destination.
///
/// ```swift
/// // Roll the output every minute.
/// Tick(60, .seconds) {
///     Freopen("/var/log/dtrace-%d.log", "walltimestamp")
/// }
/// ```
public struct Freopen: Sendable {
    public let component: ProbeComponent

    /// - Parameters:
    ///   - format: `printf`-style format that yields the new pathname.
    ///   - args: D expressions substituted into `format`.
    public init(_ format: String, _ args: String...) {
        let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("freopen(\"\(format)\"\(argList));"))
    }

    /// Reverts trace output to the original destination.
    public static var revert: Freopen {
        Freopen("")
    }
}

extension Freopen: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

// MARK: - Destructive Actions
//
// These actions require destructive mode (`-w` on the command line, or
// `dtrace_destructive_disallow=0` set on the running kernel). Without
// it the script will fail to enable.

/// Sends a signal to the traced process.
///
/// `raise(sig)` is a destructive action: it requires DTrace's
/// destructive mode (`-w` or the `destructive` option) to be enabled.
/// Use it sparingly — typically to forcibly stop a process whose state
/// you've just captured for later inspection.
///
/// ```swift
/// Probe("syscall::open:entry") {
///     When("execname == \"badness\"")
///     Raise(SIGSTOP)  // freeze it for later inspection
/// }
/// ```
public struct Raise: Sendable {
    public let component: ProbeComponent

    /// - Parameter signal: Signal number to deliver (e.g. `SIGSTOP`,
    ///   `SIGTERM`).
    public init(_ signal: Int32) {
        self.component = ProbeComponent(kind: .action("raise(\(signal));"))
    }
}

extension Raise: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}

/// Runs a shell command from a probe.
///
/// `system(format, args…)` is a destructive action: it requires
/// DTrace's destructive mode. The kernel hands the command off to a
/// privileged userland helper, so it is rate-limited and must not be
/// used for high-frequency probes. Useful for "snapshot a core file
/// and continue tracing" patterns.
///
/// ```swift
/// Probe("fbt::vm_fault:entry") {
///     When("execname == \"target\"")
///     System("kill -ABRT %d", "pid")
/// }
/// ```
public struct System: Sendable {
    public let component: ProbeComponent

    /// - Parameters:
    ///   - format: `printf`-style format yielding the shell command.
    ///   - args: D expressions substituted into `format`.
    public init(_ format: String, _ args: String...) {
        let argList = args.isEmpty ? "" : ", " + args.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("system(\"\(format)\"\(argList));"))
    }
}

extension System: ProbeComponentConvertible {
    public func asProbeComponent() -> ProbeComponent { component }
}
