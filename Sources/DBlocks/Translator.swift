/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - Translator
//
// DTrace translators give you a stable, named view of an internal
// kernel struct. The system D library files (`/usr/lib/dtrace/io.d`,
// `net.d`, `procfs.d`, …) ship translators for the standard providers
// — that's how `args[0]->ip_plength` works for the `tcp` provider
// regardless of the underlying kernel struct layout.
//
// `DBlocks` consumes those system translators via the typed accessor
// namespaces in ProviderArgs.swift (``TCPArgs``, ``IOArgs``, etc.). If
// you ship your *own* USDT-instrumented application and want consumers
// to write `args[0]->sql` instead of poking at internal C structs,
// you also need to ship a translator. This file lets you author one
// from Swift, render it into a script's preamble, and pair it with a
// matching typed-accessor namespace.

/// A DTrace translator: a typed view over an internal struct.
///
/// A translator declares an *output* type name (e.g. `queryinfo_t`),
/// an *input* parameter declaration (the C/D type of the value being
/// translated, plus a binding name), and a list of named *fields*,
/// each defined by a D expression evaluated in the input's scope.
///
/// ```swift
/// let queryinfo = Translator(output: "queryinfo_t", input: "Query *q") {
///     Translator.Field("sql",         from: "stringof(q->raw_sql)")
///     Translator.Field("duration_ns", from: "q->elapsed_nanos")
///     Translator.Field("rows",        from: "q->result_rowcount")
/// }
///
/// var script = DBlocks { /* probes */ }
/// script.declare(.translator(queryinfo))
/// ```
///
/// The rendered D form looks like:
///
/// ```d
/// translator queryinfo_t < Query *q > {
///     sql = stringof(q->raw_sql);
///     duration_ns = q->elapsed_nanos;
///     rows = q->result_rowcount;
/// };
/// ```
///
/// Pair this with a hand-written typed-accessor namespace (see
/// ``TypedTranslator`` for the recommended pattern) so callers can
/// autocomplete `MyArgs.sql` and have it render the correct `args[N]`
/// access.
public struct Translator: Sendable, Codable, Equatable {
    /// The translated-to type name (e.g. `"queryinfo_t"`).
    public let outputType: String

    /// The input parameter declaration, including the binding name
    /// used by the field expressions (e.g. `"Query *q"`).
    public let inputType: String

    /// Ordered list of fields the translator exposes.
    public let fields: [Field]

    /// A single field of a translator: a name and the D expression
    /// (or `DExpr`) that produces its value.
    public struct Field: Sendable, Codable, Equatable {
        /// The field's name on the *output* side.
        public let name: String

        /// The D expression evaluated against the input binding.
        public let expression: String

        public init(_ name: String, from expression: String) {
            self.name = name
            self.expression = expression
        }

        public init(_ name: String, from expression: DExpr) {
            self.name = name
            self.expression = expression.rendered
        }
    }

    public init(output: String, input: String, fields: [Field]) {
        self.outputType = output
        self.inputType = input
        self.fields = fields
    }

    /// Result-builder form for the field list. Identical to the
    /// array form but reads more naturally for hand-written
    /// translators.
    public init(
        output: String,
        input: String,
        @TranslatorBuilder fields: () -> [Field]
    ) {
        self.outputType = output
        self.inputType = input
        self.fields = fields()
    }

    /// Renders the translator as a D `translator { … }` block.
    public func render() -> String {
        var s = "translator \(outputType) < \(inputType) > {\n"
        for f in fields {
            s += "    \(f.name) = \(f.expression);\n"
        }
        s += "};"
        return s
    }
}

/// Result builder for ``Translator`` field lists.
@resultBuilder
public struct TranslatorBuilder {
    public static func buildBlock(_ components: [Translator.Field]...) -> [Translator.Field] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[Translator.Field]]) -> [Translator.Field] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [Translator.Field]?) -> [Translator.Field] {
        component ?? []
    }

    public static func buildEither(first component: [Translator.Field]) -> [Translator.Field] {
        component
    }

    public static func buildEither(second component: [Translator.Field]) -> [Translator.Field] {
        component
    }

    public static func buildExpression(_ expression: Translator.Field) -> [Translator.Field] {
        [expression]
    }
}

// MARK: - Typedef
//
// DTrace translators usually need a matching `typedef struct { ... }`
// somewhere — either in a system header or in the script preamble —
// so the compiler knows what fields the output type has. Authoring
// one from Swift mirrors the translator API.

/// A C-style `typedef struct { … } NAME;` declaration. Used in
/// concert with ``Translator`` to declare the output type's shape
/// before the translator block references its fields.
///
/// ```swift
/// let queryinfoType = Typedef(name: "queryinfo_t") {
///     Typedef.Member("sql",         type: "string")
///     Typedef.Member("duration_ns", type: "int")
///     Typedef.Member("rows",        type: "int")
/// }
///
/// script.declare(.typedef(queryinfoType))
/// ```
public struct Typedef: Sendable, Codable, Equatable {
    /// The typedef'd type name (e.g. `"queryinfo_t"`).
    public let name: String

    /// Ordered list of struct members.
    public let members: [Member]

    /// One field of a `typedef struct`: a name and a D type.
    public struct Member: Sendable, Codable, Equatable {
        public let name: String
        public let type: String

        public init(_ name: String, type: String) {
            self.name = name
            self.type = type
        }
    }

    public init(name: String, members: [Member]) {
        self.name = name
        self.members = members
    }

    public init(name: String, @TypedefBuilder members: () -> [Member]) {
        self.name = name
        self.members = members()
    }

    public func render() -> String {
        var s = "typedef struct {\n"
        for m in members {
            s += "    \(m.type) \(m.name);\n"
        }
        s += "} \(name);"
        return s
    }
}

/// Result builder for ``Typedef`` member lists.
@resultBuilder
public struct TypedefBuilder {
    public static func buildBlock(_ components: [Typedef.Member]...) -> [Typedef.Member] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[Typedef.Member]]) -> [Typedef.Member] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: Typedef.Member) -> [Typedef.Member] {
        [expression]
    }
}

// MARK: - Declaration
//
// Top-level entries that go in a script's preamble — before the first
// probe clause. The variants cover everything DTrace's grammar allows
// at the top level except for probe definitions themselves.

/// A top-level declaration in a DTrace script's preamble.
///
/// Declarations render in the order they were added, before any
/// probe clauses. Use ``DBlocks/declare(_:)`` to attach one to a
/// script.
public enum Declaration: Sendable, Equatable {
    /// `#pragma D option NAME` or `#pragma D option NAME=VALUE`.
    /// Equivalent to `DTraceSession.option(_:value:)` but baked
    /// into the script source — useful when exporting a standalone
    /// `.d` file for `dtrace -s`.
    case pragma(name: String, value: String?)

    /// `#pragma D depends_on library NAME` — explicit dependency
    /// on another D library file.
    case dependsOn(library: String)

    /// A `typedef struct { … } NAME;` declaration.
    case typedef(Typedef)

    /// A `translator OUT < IN > { … };` declaration. The
    /// first-class way to ship a custom typed view over an
    /// application-internal struct.
    case translator(Translator)

    /// `inline TYPE NAME = VALUE;` — a compile-time constant.
    case inlineConstant(type: String, name: String, value: String)

    /// `self TYPE NAME;` — declares a thread-local with an
    /// explicit type. Optional in DTrace (the type is normally
    /// inferred from the first assignment), but useful for
    /// readability and to lock in a specific size.
    case threadLocalDecl(type: String, name: String)

    /// `this TYPE NAME;` — explicit clause-local declaration.
    case clauseLocalDecl(type: String, name: String)

    /// Verbatim D source for a top-level declaration. Use this as
    /// an escape hatch for grammar the typed cases don't model.
    case raw(String)

    /// Renders this declaration as the corresponding D source.
    public func render() -> String {
        switch self {
        case .pragma(let name, let value):
            if let v = value {
                return "#pragma D option \(name)=\(v)"
            } else {
                return "#pragma D option \(name)"
            }
        case .dependsOn(let library):
            return "#pragma D depends_on library \(library)"
        case .typedef(let t):
            return t.render()
        case .translator(let t):
            return t.render()
        case .inlineConstant(let type, let name, let value):
            return "inline \(type) \(name) = \(value);"
        case .threadLocalDecl(let type, let name):
            return "self \(type) \(name);"
        case .clauseLocalDecl(let type, let name):
            return "this \(type) \(name);"
        case .raw(let source):
            return source
        }
    }
}

extension Declaration: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case name
        case value
        case library
        case typedef
        case translator
        case type
        case constantValue
        case source
    }

    private enum Kind: String, Codable {
        case pragma
        case dependsOn
        case typedef
        case translator
        case inlineConstant
        case threadLocalDecl
        case clauseLocalDecl
        case raw
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .pragma:
            self = .pragma(
                name: try c.decode(String.self, forKey: .name),
                value: try c.decodeIfPresent(String.self, forKey: .value)
            )
        case .dependsOn:
            self = .dependsOn(library: try c.decode(String.self, forKey: .library))
        case .typedef:
            self = .typedef(try c.decode(Typedef.self, forKey: .typedef))
        case .translator:
            self = .translator(try c.decode(Translator.self, forKey: .translator))
        case .inlineConstant:
            self = .inlineConstant(
                type: try c.decode(String.self, forKey: .type),
                name: try c.decode(String.self, forKey: .name),
                value: try c.decode(String.self, forKey: .constantValue)
            )
        case .threadLocalDecl:
            self = .threadLocalDecl(
                type: try c.decode(String.self, forKey: .type),
                name: try c.decode(String.self, forKey: .name)
            )
        case .clauseLocalDecl:
            self = .clauseLocalDecl(
                type: try c.decode(String.self, forKey: .type),
                name: try c.decode(String.self, forKey: .name)
            )
        case .raw:
            self = .raw(try c.decode(String.self, forKey: .source))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pragma(let name, let value):
            try c.encode(Kind.pragma, forKey: .kind)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(value, forKey: .value)
        case .dependsOn(let library):
            try c.encode(Kind.dependsOn, forKey: .kind)
            try c.encode(library, forKey: .library)
        case .typedef(let t):
            try c.encode(Kind.typedef, forKey: .kind)
            try c.encode(t, forKey: .typedef)
        case .translator(let t):
            try c.encode(Kind.translator, forKey: .kind)
            try c.encode(t, forKey: .translator)
        case .inlineConstant(let type, let name, let value):
            try c.encode(Kind.inlineConstant, forKey: .kind)
            try c.encode(type, forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(value, forKey: .constantValue)
        case .threadLocalDecl(let type, let name):
            try c.encode(Kind.threadLocalDecl, forKey: .kind)
            try c.encode(type, forKey: .type)
            try c.encode(name, forKey: .name)
        case .clauseLocalDecl(let type, let name):
            try c.encode(Kind.clauseLocalDecl, forKey: .kind)
            try c.encode(type, forKey: .type)
            try c.encode(name, forKey: .name)
        case .raw(let source):
            try c.encode(Kind.raw, forKey: .kind)
            try c.encode(source, forKey: .source)
        }
    }
}

// MARK: - TypedTranslator
//
// The recommended pattern for "DBlocks-first" translators: pair a
// `Translator` value with a Swift namespace that exposes the same
// fields as static `DExpr` properties. This is the same shape as
// `TCPArgs`, `IOArgs`, etc. — when a probe fires with `args[0]`
// pointing at your translated type, callers write
// `MyArgs.fieldName` instead of remembering the field name as a
// string.
//
// Conform an uninhabited enum to `TypedTranslator` and provide a
// `translator` static property; the protocol gives you a
// `register(in:)` helper that adds the translator (and any
// associated typedef) to a script in one call.

/// Marker protocol for a Swift namespace that pairs with a
/// ``Translator``. The conforming type is normally an uninhabited
/// `enum` whose static `DExpr` properties expose `args[N]` accessors
/// for each field of the underlying translator.
///
/// ```swift
/// public enum QueryArgs: TypedTranslator {
///     public static let translator = Translator(
///         output: "queryinfo_t", input: "Query *q"
///     ) {
///         Translator.Field("sql",         from: "stringof(q->raw_sql)")
///         Translator.Field("duration_ns", from: "q->elapsed_nanos")
///         Translator.Field("rows",        from: "q->result_rowcount")
///     }
///
///     public static let typedef: Typedef? = Typedef(name: "queryinfo_t") {
///         Typedef.Member("sql",         type: "string")
///         Typedef.Member("duration_ns", type: "int")
///         Typedef.Member("rows",        type: "int")
///     }
///
///     public static var sql:        DExpr { DExpr("args[0]->sql") }
///     public static var durationNs: DExpr { DExpr("args[0]->duration_ns") }
///     public static var rows:       DExpr { DExpr("args[0]->rows") }
/// }
///
/// var script = DBlocks { /* probes */ }
/// QueryArgs.register(in: &script)
/// ```
public protocol TypedTranslator {
    /// The translator definition. Will be added to the script's
    /// preamble when ``register(in:)`` is called.
    static var translator: Translator { get }

    /// Optional matching `typedef`. Set to `nil` if the output type
    /// is already declared in a system header.
    static var typedef: Typedef? { get }
}

extension TypedTranslator {
    /// Default: no typedef. Override if your output type isn't
    /// already declared elsewhere.
    public static var typedef: Typedef? { nil }

    /// Adds the translator (and its typedef, if any) to the given
    /// script's preamble.
    ///
    /// **Idempotent**: a second call against the same script is a
    /// no-op. The check matches by output-type name, so re-registering
    /// the same `TypedTranslator` does not produce duplicate
    /// declarations even when invoked from multiple call sites.
    public static func register(in script: inout DBlocks) {
        let outputName = translator.outputType

        // Already-registered? Look for a translator declaration with
        // the same output type. We deliberately don't compare the
        // full struct so that two slight variants of the same
        // translator are still treated as one (the first one wins).
        for d in script.declarations {
            if case .translator(let t) = d, t.outputType == outputName {
                return
            }
        }

        if let td = typedef {
            // Skip the typedef too if an identically-named one is
            // already in the preamble.
            let alreadyHasTypedef = script.declarations.contains { decl in
                if case .typedef(let existing) = decl, existing.name == td.name {
                    return true
                }
                return false
            }
            if !alreadyHasTypedef {
                script.declare(.typedef(td))
            }
        }
        script.declare(.translator(translator))
    }
}
