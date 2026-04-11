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

    /// `curpsinfo` — pointer to the `psinfo_t` for the current
    /// process, exposing fields like `pr_psargs`, `pr_fname`,
    /// `pr_pid`, `pr_uid`, `pr_gid`. Use member access via the
    /// rendered `->` form.
    public static let curpsinfo     = DExpr("curpsinfo")

    /// `curlwpsinfo` — pointer to the `lwpsinfo_t` for the current
    /// LWP, exposing per-thread fields like `pr_state`, `pr_pri`,
    /// `pr_stype`, `pr_lwpid`.
    public static let curlwpsinfo   = DExpr("curlwpsinfo")

    /// `curcpu` — pointer to the `cpuinfo_t` for the CPU on which
    /// the current probe fired, exposing `cpu_id`, `cpu_pset`, etc.
    public static let curcpu        = DExpr("curcpu")

    /// `cpuinfo` — alias for `curcpu` in some DTrace dialects;
    /// rendered identically. Provided for symmetry with documentation.
    public static let cpuinfo       = DExpr("curcpu")

    /// `errno` — the value of `errno` after the probe completes.
    /// Only meaningful inside `:return` probes.
    public static let errno         = DExpr("errno")

    /// `arg0` … `arg9` shorthand for the most common argument
    /// indices. Equivalent to ``arg(_:)`` but available as static
    /// properties for autocomplete-friendly use in predicates.
    public static let arg0 = DExpr("arg0")
    public static let arg1 = DExpr("arg1")
    public static let arg2 = DExpr("arg2")
    public static let arg3 = DExpr("arg3")
    public static let arg4 = DExpr("arg4")
    public static let arg5 = DExpr("arg5")
    public static let arg6 = DExpr("arg6")
    public static let arg7 = DExpr("arg7")
    public static let arg8 = DExpr("arg8")
    public static let arg9 = DExpr("arg9")
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

    // MARK: - String functions
    //
    // The full string-manipulation family DTrace's libdtrace exposes.
    // Each helper produces a `DExpr` whose rendered form is the literal
    // D function call, ready to drop into a `Printf` argument or a
    // `When` predicate.

    /// `strjoin(a, b)` — concatenate two strings into a new
    /// scratch-buffer string.
    public static func strjoin(_ a: DExpr, _ b: DExpr) -> DExpr {
        DExpr("strjoin(\(a.rendered), \(b.rendered))")
    }

    /// `strtok(s, delim)` — return the next token from `s` using
    /// `delim` as the separator set, the same way `strtok(3)` does.
    /// Pass `NULL` (or a `DExpr` rendering to `(char *)NULL`) for
    /// continued scans within the same probe firing.
    public static func strtok(_ s: DExpr, _ delim: DExpr) -> DExpr {
        DExpr("strtok(\(s.rendered), \(delim.rendered))")
    }

    /// `strstr(haystack, needle)` — pointer to the first occurrence
    /// of `needle` inside `haystack`, or `NULL` if not found.
    public static func strstr(_ haystack: DExpr, _ needle: DExpr) -> DExpr {
        DExpr("strstr(\(haystack.rendered), \(needle.rendered))")
    }

    /// `index(haystack, needle)` — index of the first occurrence of
    /// `needle` in `haystack`, or `-1`. The two-argument form.
    public static func indexOf(_ haystack: DExpr, _ needle: DExpr) -> DExpr {
        DExpr("index(\(haystack.rendered), \(needle.rendered))")
    }

    /// `rindex(haystack, needle)` — index of the *last* occurrence
    /// of `needle` in `haystack`, or `-1`.
    public static func rindexOf(_ haystack: DExpr, _ needle: DExpr) -> DExpr {
        DExpr("rindex(\(haystack.rendered), \(needle.rendered))")
    }

    /// `strchr(s, c)` — pointer to the first occurrence of character
    /// `c` in `s`, or `NULL`.
    public static func strchr(_ s: DExpr, _ c: DExpr) -> DExpr {
        DExpr("strchr(\(s.rendered), \(c.rendered))")
    }

    /// `strrchr(s, c)` — pointer to the last occurrence of `c` in
    /// `s`, or `NULL`.
    public static func strrchr(_ s: DExpr, _ c: DExpr) -> DExpr {
        DExpr("strrchr(\(s.rendered), \(c.rendered))")
    }

    /// `dirname(path)` — directory portion of `path`, à la
    /// `dirname(3)`.
    public static func dirname(_ path: DExpr) -> DExpr {
        DExpr("dirname(\(path.rendered))")
    }

    /// `basename(path)` — final filename component of `path`.
    public static func basename(_ path: DExpr) -> DExpr {
        DExpr("basename(\(path.rendered))")
    }

    /// `lltostr(value)` — render an `int64_t` as its decimal string
    /// representation in a scratch buffer.
    public static func lltostr(_ value: DExpr) -> DExpr {
        DExpr("lltostr(\(value.rendered))")
    }

    /// `inet_ntoa(addr)` — render an IPv4 address (as `ipaddr_t *`)
    /// in dotted-quad form.
    public static func inetNtoa(_ address: DExpr) -> DExpr {
        DExpr("inet_ntoa(\(address.rendered))")
    }

    /// `inet_ntoa6(addr)` — render an IPv6 address (as
    /// `in6_addr_t *`) in canonical form.
    public static func inetNtoa6(_ address: DExpr) -> DExpr {
        DExpr("inet_ntoa6(\(address.rendered))")
    }

    /// `inet_ntop(af, addr)` — render either an IPv4 or IPv6 address
    /// based on the address family. Pass `AF_INET` or `AF_INET6` as
    /// the first argument.
    public static func inetNtop(_ family: DExpr, _ address: DExpr) -> DExpr {
        DExpr("inet_ntop(\(family.rendered), \(address.rendered))")
    }

    // MARK: - Member access
    //
    // For typed pointers like `curpsinfo` or `args[2]`, dereferencing
    // a struct field uses `->` in D. The Swift dot operator can't be
    // overloaded to render that, so we provide a `member(_:)`
    // helper that takes the field name and produces the rendered
    // `expr->name` form.

    /// `expr->member` — struct/pointer member access in D. Use this
    /// to chain off typed pointers like `curpsinfo` or `args[N]`.
    ///
    /// ```swift
    /// DExpr.curpsinfo.member("pr_fname")  // → curpsinfo->pr_fname
    /// DExpr.args(1).member("pr_pid")      // → args[1]->pr_pid
    /// ```
    public func member(_ name: String) -> DExpr {
        DExpr("\(self.rendered)->\(name)")
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
//
// All comparison operators take a left-hand `DExpr` and either another
// `DExpr`, an `Int`, or a `String` on the right. The result is a
// `DExpr` that renders as the corresponding D-language comparison
// (`==`, `!=`, `<`, `<=`, `>`, `>=`). String literals on the right
// are automatically quoted, so `DExpr.execname == "nginx"` renders as
// `execname == "nginx"`. These operators do not introduce extra
// parentheses around their operands; group with parentheses in Swift
// when needed.

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
//
// `+`, `-`, `*`, `/` produce a `DExpr` whose rendered form wraps the
// operands in parentheses (`(lhs OP rhs)`). The parentheses preserve
// the intended grouping when the result is then composed into a
// larger expression — without them, naive concatenation would mis-
// associate against D's own operator precedence.

public func + (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) + \(rhs.rendered))") }
public func - (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) - \(rhs.rendered))") }
public func * (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) * \(rhs.rendered))") }
public func / (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered) / \(rhs.rendered))") }

public func + (lhs: DExpr, rhs: Int) -> DExpr { DExpr("(\(lhs.rendered) + \(rhs))") }
public func - (lhs: DExpr, rhs: Int) -> DExpr { DExpr("(\(lhs.rendered) - \(rhs))") }

// MARK: - Logical
//
// `&&`, `||`, and the prefix `!` produce a `DExpr` whose rendered
// form fully parenthesizes both operands so the result composes
// safely inside larger predicates. `When(.a && .b)` and
// `When(!(.a == 1))` are the typical entry points.

public func && (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered)) && (\(rhs.rendered))") }
public func || (lhs: DExpr, rhs: DExpr) -> DExpr { DExpr("(\(lhs.rendered)) || (\(rhs.rendered))") }
public prefix func ! (rhs: DExpr) -> DExpr { DExpr("!(\(rhs.rendered))") }

// MARK: - Ternary
//
// DTrace's D language has no `if`/`else`, but it does have C's ternary
// operator (`cond ? a : b`). This is the only way to embed conditional
// logic inside an action body, and it shows up constantly in real
// scripts (e.g. classifying a syscall return as success/failure before
// aggregating it). Swift does not let us overload `?:`, so we expose
// the operation as a static helper plus an instance shorthand.

extension DExpr {

    /// Builds a C-style ternary expression: `condition ? then : else`.
    ///
    /// All three operands are arbitrary `DExpr` fragments. The result is
    /// fully parenthesized so it composes safely inside larger
    /// expressions.
    ///
    /// ```swift
    /// // Classify a read return as "ok" or "err" before aggregating it.
    /// Printf("%s",
    ///        args: [.ternary(.arg(0) >= 0, then: DExpr("\"ok\""), else: DExpr("\"err\""))])
    /// ```
    public static func ternary(_ condition: DExpr, then a: DExpr, else b: DExpr) -> DExpr {
        DExpr("(\(condition.rendered) ? \(a.rendered) : \(b.rendered))")
    }

    /// Instance form of ``ternary(_:then:else:)`` — reads as
    /// "this condition `?` a `:` b".
    ///
    /// ```swift
    /// let status = (DExpr.arg(0) >= 0).then(DExpr("\"ok\""), else: DExpr("\"err\""))
    /// ```
    public func then(_ a: DExpr, else b: DExpr) -> DExpr {
        DExpr.ternary(self, then: a, else: b)
    }
}

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
