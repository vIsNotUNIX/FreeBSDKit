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
}
