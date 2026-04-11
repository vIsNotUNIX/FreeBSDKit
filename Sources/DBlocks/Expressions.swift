/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - DExpr

/// A typed wrapper around a fragment of D source that evaluates to a
/// value at probe-firing time.
///
/// `DExpr` is a thin layer that lets you build predicates and arguments
/// using Swift operators and constructors instead of raw strings.
/// Everything ultimately renders to the same D code; the value of this
/// type is **typo-protection**, **autocomplete**, and being able to
/// build expressions out of helper functions.
///
/// ```swift
/// // Equivalent forms:
/// When("arg0 > 0")
/// When(.arg(0) > 0)
///
/// // Equivalent forms:
/// Printf("%s[%d]", "execname", "pid")
/// Printf("%s[%d]", args: [.execname, .pid])
/// ```
///
/// `DExpr` is **not** a parser. It does no validation of the contained
/// fragment beyond what Swift's operators give you (e.g. comparing
/// `.arg(0) > 0` produces a predicate, but `.arg(0) > "string"` would
/// be rejected by Swift's type checker).
///
/// `DExpr` deliberately does **not** conform to
/// `ExpressibleByStringLiteral`. Allowing implicit string conversion
/// would defeat the type-safety story (and would also collide with the
/// existing `Printf(_:_:String...)` initializer). When you really do
/// want a raw fragment, write `DExpr("...")` explicitly.
public struct DExpr: Sendable, Equatable, CustomStringConvertible {

    /// The rendered D fragment.
    public let rendered: String

    public init(_ rendered: String) {
        self.rendered = rendered
    }

    public var description: String { rendered }
}

// MARK: - Built-in variables

extension DExpr {

    /// `arg0`, `arg1`, ... — the indexed arguments to the current probe.
    ///
    /// What `argN` actually contains depends on the probe provider:
    /// for `syscall:::entry` it is the syscall argument, for
    /// `fbt:::entry` it is the C function argument, for the `io`
    /// provider it is a pointer to a `bufinfo_t`/`devinfo_t`, and so on.
    public static func arg(_ index: Int) -> DExpr {
        DExpr("arg\(index)")
    }

    /// Reference to a typed argument record (`args[N]`). Use this for
    /// providers like `tcp`, `io`, and `proc` whose `argN` slots are
    /// typedef'd structs.
    public static func args(_ index: Int) -> DExpr {
        DExpr("args[\(index)]")
    }

    // Common probe-context variables. These are *constants* the kernel
    // exposes for the current probe firing — wrapping them as static
    // properties is mostly about discoverability.

    public static let pid           = DExpr("pid")
    public static let tid           = DExpr("tid")
    public static let execname      = DExpr("execname")
    public static let probefunc     = DExpr("probefunc")
    public static let probemod      = DExpr("probemod")
    public static let probeprov     = DExpr("probeprov")
    public static let probename     = DExpr("probename")
    public static let timestamp     = DExpr("timestamp")
    public static let vtimestamp    = DExpr("vtimestamp")
    public static let walltimestamp = DExpr("walltimestamp")
    public static let cpu           = DExpr("cpu")
    public static let stack         = DExpr("stack()")
    public static let ustack        = DExpr("ustack()")
    public static let uid           = DExpr("uid")
    public static let gid           = DExpr("gid")
    public static let ppid          = DExpr("ppid")
    public static let curthread     = DExpr("curthread")
}

// MARK: - Macro arguments
//
// dtrace -s script.d arg1 arg2 ... fills in $1/$$1/etc. Use these to
// reference them safely.

extension DExpr {

    /// `$target` — the PID of a process attached via
    /// `DTraceSession.attach(to:)` or launched via
    /// `DTraceSession.spawn(path:arguments:)`.
    public static let target = DExpr("$target")

    /// `$1`, `$2`, ... — numeric command-line macro arguments.
    public static func macro(_ position: Int) -> DExpr {
        DExpr("$\(position)")
    }

    /// `$$1`, `$$2`, ... — string command-line macro arguments
    /// (already quoted by the dtrace driver).
    public static func macroString(_ position: Int) -> DExpr {
        DExpr("$$\(position)")
    }
}

// MARK: - Function calls and casts

extension DExpr {

    /// `copyinstr(addr)` — read a NUL-terminated string from a user
    /// address. The most common use is reading the path argument of
    /// open/exec/etc.
    public static func copyinstr(_ address: DExpr) -> DExpr {
        DExpr("copyinstr(\(address.rendered))")
    }

    /// `copyin(addr, size)` — read `size` bytes from a user address.
    public static func copyin(_ address: DExpr, _ size: Int) -> DExpr {
        DExpr("copyin(\(address.rendered), \(size))")
    }

    /// `stringof(value)` — convert a numeric value to its string form.
    public static func stringof(_ value: DExpr) -> DExpr {
        DExpr("stringof(\(value.rendered))")
    }

    /// `strlen(value)` — length of a string.
    public static func strlen(_ value: DExpr) -> DExpr {
        DExpr("strlen(\(value.rendered))")
    }

    /// `(type)expr` — explicit cast.
    public static func cast(_ expression: DExpr, to type: String) -> DExpr {
        DExpr("(\(type))\(expression.rendered)")
    }
}

// MARK: - Variables (typed)

extension DExpr {

    /// `self->name` — thread-local read.
    public static func threadLocal(_ name: String) -> DExpr {
        DExpr("self->\(name)")
    }

    /// `this->name` — clause-local read.
    public static func clauseLocal(_ name: String) -> DExpr {
        DExpr("this->\(name)")
    }

    /// Reference an existing typed variable.
    public static func variable(_ variable: Var) -> DExpr {
        DExpr(variable.expression)
    }
}

// MARK: - Comparison operators

public func == (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) == \(rhs.rendered)") }
public func != (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) != \(rhs.rendered)") }
public func <  (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) < \(rhs.rendered)")  }
public func <= (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) <= \(rhs.rendered)") }
public func >  (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) > \(rhs.rendered)")  }
public func >= (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("\(lhs.rendered) >= \(rhs.rendered)") }

public func == (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) == \(rhs)") }
public func != (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) != \(rhs)") }
public func <  (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) < \(rhs)")  }
public func <= (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) <= \(rhs)") }
public func >  (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) > \(rhs)")  }
public func >= (lhs: DExpr, rhs: Int)    -> DExpr { DExpr("\(lhs.rendered) >= \(rhs)") }

public func == (lhs: DExpr, rhs: String) -> DExpr { DExpr("\(lhs.rendered) == \"\(rhs)\"") }
public func != (lhs: DExpr, rhs: String) -> DExpr { DExpr("\(lhs.rendered) != \"\(rhs)\"") }

// MARK: - Arithmetic

public func + (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) + \(rhs.rendered))") }
public func - (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) - \(rhs.rendered))") }
public func * (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) * \(rhs.rendered))") }
public func / (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) / \(rhs.rendered))") }

public func + (lhs: DExpr, rhs: Int) -> DExpr { DExpr("(\(lhs.rendered) + \(rhs))") }
public func - (lhs: DExpr, rhs: Int) -> DExpr { DExpr("(\(lhs.rendered) - \(rhs))") }

// MARK: - Logical

public func && (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered)) && (\(rhs.rendered))") }
public func || (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered)) || (\(rhs.rendered))") }
public prefix func ! (rhs: DExpr) -> DExpr { DExpr("!(\(rhs.rendered))") }

// MARK: - When / Printf bridges

extension When {
    /// Construct a `When` predicate from a typed `DExpr`.
    ///
    /// ```swift
    /// When(.arg(0) > 0)
    /// When(.execname == "nginx" && .arg(0) > 100)
    /// ```
    public init(_ expression: DExpr) {
        self.init(expression.rendered)
    }
}

extension Printf {
    /// Construct a `Printf` action from a format string and a list of
    /// typed `DExpr` values.
    ///
    /// The named `args:` label is required to disambiguate from the
    /// existing string-only `Printf(_:_:)` initializer.
    ///
    /// ```swift
    /// Printf("%s[%d]: %s",
    ///        args: [.execname, .pid, .copyinstr(.arg(0))])
    /// ```
    public init(_ format: String, args: [DExpr]) {
        let argList = args.isEmpty ? "" : ", " + args.map { $0.rendered }.joined(separator: ", ")
        self.component = ProbeComponent(kind: .action("printf(\"\(format)\\n\"\(argList));"))
    }
}

extension Trace {
    /// Trace a typed expression.
    public init(_ expression: DExpr) {
        self.init(expression.rendered)
    }
}
