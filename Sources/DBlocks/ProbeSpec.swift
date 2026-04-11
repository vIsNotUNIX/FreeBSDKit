/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Probe Spec

/// A typed builder for DTrace probe specifications.
///
/// A DTrace probe is identified by a four-field tuple
/// `provider:module:function:name`. Most callers can keep using the
/// existing `Probe("syscall:::entry")` form with a raw string, but
/// `ProbeSpec` adds:
///
/// - **autocomplete in Xcode** for the common providers
/// - **fewer typos** (no need to remember whether `read:return` is
///   spelled with `freebsd` or `:::`)
/// - **wildcards by omission** — any field left empty matches every
///   value at that position, the same way the raw spec does
///
/// ## Example
///
/// ```swift
/// // Equivalent forms:
/// Probe("syscall:freebsd:read:entry") { ... }
/// Probe(.syscall("read", .entry)) { ... }
///
/// // Wildcards are explicit:
/// Probe(.fbt(module: "kernel", function: "uipc_send", .entry))
/// Probe(.proc(.execSuccess))
/// Probe(.tcp(.stateChange))
///
/// // Custom escape hatch:
/// Probe(.custom(provider: "myprov", function: "*", name: "entry"))
/// ```
public struct ProbeSpec: Sendable, Hashable, CustomStringConvertible {

    public let provider: String
    public let module: String
    public let function: String
    public let name: String

    /// Build a fully-qualified probe spec from its four fields. Pass an
    /// empty string for any field to wildcard it.
    public init(
        provider: String,
        module: String = "",
        function: String = "",
        name: String = ""
    ) {
        self.provider = provider
        self.module = module
        self.function = function
        self.name = name
    }

    /// The `provider:module:function:name` form expected by DTrace.
    public var rendered: String {
        "\(provider):\(module):\(function):\(name)"
    }

    public var description: String { rendered }
}

// MARK: - Common probe shapes

extension ProbeSpec {

    // syscall provider --------------------------------------------------

    /// Marks the entry or return of a syscall.
    public enum SyscallSite: String, Sendable {
        case entry
        case `return`
    }

    /// FreeBSD syscall probe.
    ///
    /// ```swift
    /// Probe(.syscall("read", .entry))    // syscall:freebsd:read:entry
    /// Probe(.syscall("*",    .return))   // syscall:freebsd:*:return
    /// ```
    public static func syscall(_ function: String, _ site: SyscallSite) -> ProbeSpec {
        ProbeSpec(provider: "syscall", module: "freebsd", function: function, name: site.rawValue)
    }

    // fbt provider ------------------------------------------------------

    /// Function-boundary tracing probe site.
    public enum FBTSite: String, Sendable {
        case entry
        case `return`
    }

    /// Function-boundary tracing probe.
    ///
    /// ```swift
    /// Probe(.fbt(module: "kernel", function: "uipc_send", .entry))
    /// ```
    public static func fbt(module: String, function: String, _ site: FBTSite) -> ProbeSpec {
        ProbeSpec(provider: "fbt", module: module, function: function, name: site.rawValue)
    }

    // kinst provider ----------------------------------------------------

    /// Kernel instruction tracing probe.
    ///
    /// `kinst` (kernel INSTruction tracing) lets DTrace hook an
    /// arbitrary instruction inside a kernel function by its byte
    /// offset from the function start. Compared to ``fbt(module:function:_:)``,
    /// which only exposes function entry and return, `kinst` can hit
    /// any instruction in the function — at the cost of being
    /// on-demand (no `dtrace -l -P kinst` enumeration).
    ///
    /// Find the byte offset by disassembling the function with
    /// `kgdb`'s `disas /r`:
    ///
    /// ```text
    /// (kgdb) disas /r vm_fault
    ///    <+0>:  55              push   %rbp        ← .kinst(function: "vm_fault", offset: 0)
    ///    <+1>:  48 89 e5        mov    %rsp,%rbp   ← .kinst(function: "vm_fault", offset: 1)
    ///    <+4>:  41 57           push   %r15        ← .kinst(function: "vm_fault", offset: 4)
    /// ```
    ///
    /// Pass `offset: nil` (the default) to trace **every** instruction
    /// in the function — useful as a firehose, dangerous on hot paths.
    ///
    /// ```swift
    /// // Trace the third instruction in vm_fault and print RSI
    /// Probe(.kinst(function: "vm_fault", offset: 4)) {
    ///     Printf("%#x", "regs[R_RSI]")
    /// }
    ///
    /// // Trace every instruction in amd64_syscall
    /// Probe(.kinst(function: "amd64_syscall")) {
    ///     Count(by: "probename")
    /// }
    /// ```
    ///
    /// - Important: KINST first appeared in **FreeBSD 14.0**. As of
    ///   FreeBSD 15 the provider is implemented for **amd64,
    ///   aarch64, and riscv**; i386, arm, and powerpc are not
    ///   supported. The `dtrace_kinst(4)` man page on some 14.x and
    ///   15.x systems still says "amd64 only" — that documentation
    ///   is stale, the code itself supports the three architectures
    ///   above. On unsupported architectures the script compiles but
    ///   enabling probes fails at runtime with a
    ///   provider-not-available error.
    ///
    /// - Parameters:
    ///   - function: Kernel function name (no `module:` qualifier —
    ///     `kinst` resolves the symbol against the whole kernel).
    ///   - offset: Byte offset from the function start, or `nil` to
    ///     trace every instruction in the function.
    public static func kinst(function: String, offset: Int? = nil) -> ProbeSpec {
        ProbeSpec(
            provider: "kinst",
            module: "",
            function: function,
            name: offset.map(String.init) ?? ""
        )
    }

    // pid provider ------------------------------------------------------

    /// User-land function tracing site.
    public enum PIDSite: String, Sendable {
        case entry
        case `return`
    }

    /// User-land function-boundary tracing probe (`pid` provider).
    ///
    /// The `pid` provider attaches to a running user process and lets you
    /// trace function entry, function return, or arbitrary instruction
    /// offsets inside its text segment. Unlike `fbt`, which is system-wide,
    /// `pid` probes are scoped to a single PID — typically the one DTrace
    /// is told about via `$target` (i.e. `dtrace -p PID …` or
    /// `DTraceSession.attach(to:)` / `spawn(path:arguments:)`).
    ///
    /// ```swift
    /// // Trace every libc malloc entry in the target process.
    /// Probe(.pid(.target, module: "libc.so.7", function: "malloc", .entry))
    ///
    /// // Trace return from a specific app function in pid 1234.
    /// Probe(.pid(.literal(1234), module: "a.out", function: "handle_request", .return))
    ///
    /// // Trace an arbitrary instruction offset (4 bytes into malloc).
    /// Probe(.pid(.target, module: "libc.so.7", function: "malloc", offset: 4))
    /// ```
    ///
    /// - Parameters:
    ///   - process: Which process the probe attaches to. Use
    ///     ``PIDProcess/target`` for the standard `$target` macro, or
    ///     ``PIDProcess/literal(_:)`` for a hardcoded PID.
    ///   - module: Object file containing the function (e.g.
    ///     `"libc.so.7"`, `"a.out"`). Pass `""` to wildcard.
    ///   - function: Function name in `module`. Pass `""` to wildcard.
    ///   - site: `.entry` or `.return`.
    public static func pid(
        _ process: PIDProcess,
        module: String,
        function: String,
        _ site: PIDSite
    ) -> ProbeSpec {
        ProbeSpec(
            provider: "pid\(process.suffix)",
            module: module,
            function: function,
            name: site.rawValue
        )
    }

    /// User-land instruction-offset tracing probe (`pid` provider).
    ///
    /// Identical to ``pid(_:module:function:_:)`` but selects a specific
    /// byte offset inside the function rather than its entry/return.
    /// This is the user-space analogue of ``kinst(function:offset:)``.
    public static func pid(
        _ process: PIDProcess,
        module: String,
        function: String,
        offset: Int
    ) -> ProbeSpec {
        ProbeSpec(
            provider: "pid\(process.suffix)",
            module: module,
            function: function,
            name: String(offset)
        )
    }

    /// Raw-address `pid` provider probe — trace an arbitrary
    /// instruction *address* inside a user-land binary, without
    /// going through symbol resolution.
    ///
    /// This is the form to use for stripped binaries, JIT-compiled
    /// code, or any case where there is no function symbol to name.
    /// The `address` is the absolute virtual address inside the
    /// target process; the rendered probe spec uses an empty
    /// function field and the address as the probe name (libdtrace
    /// accepts both decimal and `0x`-prefixed hex).
    ///
    /// ```swift
    /// // Trace whatever is at 0x401234 in the target process.
    /// Probe(.pid(.target, module: "a.out", address: 0x401234))
    /// ```
    ///
    /// - Parameters:
    ///   - process: Which process to attach to.
    ///   - module: Object file containing the address.
    ///   - address: Absolute virtual address.
    public static func pid(
        _ process: PIDProcess,
        module: String,
        address: UInt64
    ) -> ProbeSpec {
        ProbeSpec(
            provider: "pid\(process.suffix)",
            module: module,
            function: "",
            name: String(format: "0x%llx", address)
        )
    }

    /// Selector for the process a `pid` probe attaches to.
    public enum PIDProcess: Sendable, Hashable {
        /// Attach via the `$target` macro — i.e. the process passed to
        /// `DTraceSession.attach(to:)` / `spawn(path:arguments:)` or to
        /// `dtrace -p` / `dtrace -c` on the command line.
        case target

        /// Attach to a literal numeric PID. Bakes the PID into the
        /// rendered probe name and so is not portable across runs.
        case literal(Int32)

        fileprivate var suffix: String {
            switch self {
            case .target:           return "$target"
            case .literal(let pid): return "\(pid)"
            }
        }
    }

    // USDT (user statically-defined tracing) ----------------------------

    /// User statically-defined tracing probe.
    ///
    /// USDT probes are compiled into a user-land binary by the application
    /// author (via `dtrace -h`/`-G` and `DTRACE_PROBE` macros). They are
    /// addressed by the *application's* provider name, scoped to a process
    /// the same way ``pid(_:module:function:_:)`` is.
    ///
    /// ```swift
    /// // Every postgres query-start probe in the attached target.
    /// Probe(.usdt(.target, provider: "postgresql", probe: "query-start"))
    ///
    /// // A specific function inside a specific module of pid 4242.
    /// Probe(.usdt(
    ///     .literal(4242),
    ///     provider: "myapp",
    ///     module: "libworker.so",
    ///     function: "dispatch",
    ///     probe: "request-received"
    /// ))
    /// ```
    ///
    /// - Parameters:
    ///   - process: Which process to attach to.
    ///   - provider: The application-level provider name as declared in
    ///     the `*.d` provider file (without any `$pid` suffix — that's
    ///     added automatically based on `process`).
    ///   - module: Optional object file filter. Defaults to wildcard.
    ///   - function: Optional function filter. Defaults to wildcard.
    ///   - probe: The probe name as declared in the provider file.
    public static func usdt(
        _ process: PIDProcess,
        provider: String,
        module: String = "",
        function: String = "",
        probe: String
    ) -> ProbeSpec {
        ProbeSpec(
            provider: "\(provider)\(process.suffix)",
            module: module,
            function: function,
            name: probe
        )
    }

    // proc provider -----------------------------------------------------

    /// Common probe names exposed by the `proc` provider.
    public enum ProcEvent: String, Sendable {
        case execSuccess  = "exec-success"
        case execFailure  = "exec-failure"
        case start
        case exit
        case create
        case signalSend   = "signal-send"
        case signalDiscard = "signal-discard"
    }

    /// Process-event probe.
    ///
    /// ```swift
    /// Probe(.proc(.execSuccess))
    /// Probe(.proc(.signalSend))
    /// ```
    public static func proc(_ event: ProcEvent) -> ProbeSpec {
        ProbeSpec(provider: "proc", name: event.rawValue)
    }

    // io provider -------------------------------------------------------

    /// Probe sites exposed by the `io` provider.
    public enum IOSite: String, Sendable {
        case start
        case done
        case waitStart  = "wait-start"
        case waitDone   = "wait-done"
    }

    /// Block-I/O probe.
    ///
    /// ```swift
    /// Probe(.io(.start))
    /// ```
    public static func io(_ site: IOSite) -> ProbeSpec {
        ProbeSpec(provider: "io", name: site.rawValue)
    }

    // tcp provider ------------------------------------------------------

    /// Probe names exposed by the `tcp` provider.
    public enum TCPEvent: String, Sendable {
        case sendPacket   = "send"
        case receivePacket = "receive"
        case connectRequest = "connect-request"
        case connectEstablished = "connect-established"
        case connectRefused = "connect-refused"
        case acceptEstablished = "accept-established"
        case acceptRefused = "accept-refused"
        case stateChange = "state-change"
    }

    /// TCP-event probe.
    public static func tcp(_ event: TCPEvent) -> ProbeSpec {
        ProbeSpec(provider: "tcp", name: event.rawValue)
    }

    // vminfo provider ---------------------------------------------------

    /// Probe names exposed by the `vminfo` provider.
    public enum VMEvent: String, Sendable {
        case majorFault = "maj_fault"
        case addressSpaceFault = "as_fault"
        case copyOnWrite = "cow_fault"
        case kernelFault = "kernel_asflt"
        case zeroFill   = "zfod"
    }

    /// VM/page-fault probe.
    public static func vm(_ event: VMEvent) -> ProbeSpec {
        ProbeSpec(provider: "vminfo", name: event.rawValue)
    }

    // tick / profile ----------------------------------------------------

    /// `tick-Nunit` probe — fires once per interval on a single CPU.
    ///
    /// Prefer the existing `Tick(_:_:)` clause builder when you also
    /// want to attach actions; this static is exposed mainly for
    /// callers that want to construct probe specs in isolation.
    public static func tick(_ rate: Int, _ unit: DTraceTimeUnit = .hertz) -> ProbeSpec {
        ProbeSpec(provider: "tick-\(rate)\(unit.rawValue)")
    }

    /// `profile-Nunit` probe — fires once per interval on every CPU.
    public static func profile(_ rate: Int, _ unit: DTraceTimeUnit = .hertz) -> ProbeSpec {
        ProbeSpec(provider: "profile-\(rate)\(unit.rawValue)")
    }

    // Special clauses ---------------------------------------------------

    /// `BEGIN` clause — fires once when tracing starts.
    public static let begin = ProbeSpec(provider: "BEGIN")

    /// `END` clause — fires once when tracing ends.
    public static let end = ProbeSpec(provider: "END")

    /// `ERROR` clause — fires when an action faults at runtime.
    public static let error = ProbeSpec(provider: "ERROR")

    // Escape hatch ------------------------------------------------------

    /// Build a probe spec from arbitrary fields. Use this when none of
    /// the typed convenience constructors fit.
    public static func custom(
        provider: String,
        module: String = "",
        function: String = "",
        name: String = ""
    ) -> ProbeSpec {
        ProbeSpec(provider: provider, module: module, function: function, name: name)
    }
}

// MARK: - Probe with ProbeSpec

extension ProbeClause {

    /// Builds a probe clause from a typed `ProbeSpec` instead of a raw
    /// string.
    ///
    /// ```swift
    /// Probe(.syscall("read", .entry)) {
    ///     Target(.execname("nginx"))
    ///     Count(by: "probefunc")
    /// }
    /// ```
    public init(_ spec: ProbeSpec, @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        self.init(spec.rendered, builder)
    }

    /// Builds a single probe clause that fires for *any* of the supplied
    /// probe specs, sharing one predicate-and-action body.
    ///
    /// DTrace allows a clause to list multiple probes separated by commas:
    ///
    /// ```d
    /// syscall::read:entry,
    /// syscall::write:entry
    /// {
    ///     @[probefunc] = count();
    /// }
    /// ```
    ///
    /// This initializer is the typed Swift form of that pattern.
    ///
    /// ```swift
    /// let specs: [ProbeSpec] = [
    ///     .syscall("read",  .entry),
    ///     .syscall("write", .entry),
    ///     .syscall("pread", .entry),
    /// ]
    /// Probe(specs: specs) {
    ///     Count(by: "probefunc")
    /// }
    /// ```
    ///
    /// For the common two-probe case, ``init(_:_:_:)-(ProbeSpec,ProbeSpec,_)``
    /// is a more concise form.
    ///
    /// - Precondition: `specs` must not be empty.
    public init(specs: [ProbeSpec], @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        precondition(!specs.isEmpty, "Probe(specs:) requires at least one ProbeSpec")
        self.init(specs.map(\.rendered).joined(separator: ",\n"), builder)
    }

    /// Builds a single probe clause that fires for either of two probe
    /// specs, sharing one body. Convenience for the common two-probe
    /// case; for more, use ``init(specs:_:)``.
    ///
    /// ```swift
    /// Probe(.syscall("read", .entry), .syscall("write", .entry)) {
    ///     Count(by: "probefunc")
    /// }
    /// ```
    public init(
        _ first: ProbeSpec,
        _ second: ProbeSpec,
        @ProbeClauseBuilder _ builder: () -> [ProbeComponent]
    ) {
        self.init(specs: [first, second], builder)
    }

    /// Builds a single probe clause from an array of raw probe spec
    /// strings sharing one body. This is the string-based counterpart
    /// to ``init(specs:_:)`` — useful for callers that already have
    /// raw `"syscall::read:entry"` style strings (for example because
    /// they were read from a config file or constructed at runtime).
    ///
    /// ```swift
    /// Probe(probes: ["syscall::read:entry", "syscall::write:entry"]) {
    ///     Count(by: "probefunc")
    /// }
    /// ```
    ///
    /// - Precondition: `probes` must not be empty.
    public init(probes: [String], @ProbeClauseBuilder _ builder: () -> [ProbeComponent]) {
        precondition(!probes.isEmpty, "Probe(probes:) requires at least one probe")
        self.init(probes.joined(separator: ",\n"), builder)
    }
}
