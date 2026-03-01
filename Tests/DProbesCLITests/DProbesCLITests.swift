/*
 * dprobes-cli Tests
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
import Foundation
@testable import dprobes_cli

// MARK: - Constraint Tests

@Suite("Constraints Tests")
struct ConstraintsTests {

    @Test("Max arguments is 10")
    func testMaxArguments() {
        #expect(Constraints.maxArguments == 10)
    }

    @Test("Max provider name length is 64")
    func testMaxProviderNameLength() {
        #expect(Constraints.maxProviderNameLength == 64)
    }

    @Test("Max probe name length is 64")
    func testMaxProbeNameLength() {
        #expect(Constraints.maxProbeNameLength == 64)
    }

    @Test("Valid types includes all supported Swift types")
    func testValidTypes() {
        let expected: Set<String> = [
            "Int8", "Int16", "Int32", "Int64", "Int",
            "UInt8", "UInt16", "UInt32", "UInt64", "UInt",
            "Bool", "String"
        ]
        #expect(Constraints.validTypes == expected)
    }

    @Test("Valid stabilities includes all DTrace levels")
    func testValidStabilities() {
        let expected: Set<String> = ["Private", "Project", "Evolving", "Stable", "Standard"]
        #expect(Constraints.validStabilities == expected)
    }

    @Test("Swift keywords set is not empty")
    func testSwiftKeywordsNotEmpty() {
        #expect(!Constraints.swiftKeywords.isEmpty)
        #expect(Constraints.swiftKeywords.contains("return"))
        #expect(Constraints.swiftKeywords.contains("let"))
        #expect(Constraints.swiftKeywords.contains("var"))
    }
}

// MARK: - Parser Tests

@Suite("Parser Tests")
struct ParserTests {

    @Test("Parses minimal valid JSON")
    func testMinimalJSON() throws {
        let json = """
            { "name": "test", "probes": [] }
            """
        let provider = try Parser.parse(json)
        #expect(provider.name == "test")
        #expect(provider.probes.isEmpty)
    }

    @Test("Parses probe without arguments")
    func testProbeNoArgs() throws {
        let json = """
            {
                "name": "test",
                "probes": [{ "name": "start" }]
            }
            """
        let provider = try Parser.parse(json)
        #expect(provider.probes.count == 1)
        #expect(provider.probes[0].name == "start")
        #expect(provider.probes[0].args == nil)
    }

    @Test("Parses probe with arguments")
    func testProbeWithArgs() throws {
        let json = """
            {
                "name": "test",
                "probes": [{
                    "name": "request",
                    "args": [
                        { "name": "path", "type": "String" },
                        { "name": "code", "type": "Int32" }
                    ]
                }]
            }
            """
        let provider = try Parser.parse(json)
        let args = provider.probes[0].args!
        #expect(args.count == 2)
        #expect(args[0].name == "path")
        #expect(args[0].type == "String")
        #expect(args[1].name == "code")
        #expect(args[1].type == "Int32")
    }

    @Test("Parses stability field")
    func testStability() throws {
        let json = """
            { "name": "test", "stability": "Stable", "probes": [] }
            """
        let provider = try Parser.parse(json)
        #expect(provider.stability == "Stable")
    }

    @Test("Parses docs field")
    func testDocs() throws {
        let json = """
            {
                "name": "test",
                "probes": [{ "name": "start", "docs": "Fires on start" }]
            }
            """
        let provider = try Parser.parse(json)
        #expect(provider.probes[0].docs == "Fires on start")
    }

    @Test("Parses multiple probes")
    func testMultipleProbes() throws {
        let json = """
            {
                "name": "test",
                "probes": [
                    { "name": "start" },
                    { "name": "middle" },
                    { "name": "end" }
                ]
            }
            """
        let provider = try Parser.parse(json)
        #expect(provider.probes.count == 3)
        #expect(provider.probes.map { $0.name } == ["start", "middle", "end"])
    }

    // Invalid input tests

    @Test("Throws on non-JSON input")
    func testNotJSON() {
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse("not json at all")
        }
    }

    @Test("Throws on empty string")
    func testEmptyString() {
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse("")
        }
    }

    @Test("Throws on missing name field")
    func testMissingName() {
        let json = """
            { "probes": [] }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on empty name")
    func testEmptyName() {
        let json = """
            { "name": "", "probes": [] }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on missing probes field")
    func testMissingProbes() {
        let json = """
            { "name": "test" }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on wrong type for name")
    func testNameWrongType() {
        let json = """
            { "name": 123, "probes": [] }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on wrong type for probes")
    func testProbesWrongType() {
        let json = """
            { "name": "test", "probes": "not an array" }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on probe missing name")
    func testProbeMissingName() {
        let json = """
            { "name": "test", "probes": [{ "args": [] }] }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }

    @Test("Throws on argument missing type")
    func testArgMissingType() {
        let json = """
            {
                "name": "test",
                "probes": [{
                    "name": "start",
                    "args": [{ "name": "x" }]
                }]
            }
            """
        #expect(throws: GeneratorError.self) {
            _ = try Parser.parse(json)
        }
    }
}

// MARK: - Validator Tests

@Suite("Validator Tests")
struct ValidatorTests {

    @Test("Accepts valid provider")
    func testValidProvider() throws {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: nil)]
        )
        try Validator.validate(provider)
    }

    @Test("Accepts empty probes array")
    func testEmptyProbes() throws {
        let provider = ProviderDefinition(name: "myapp", stability: nil, probes: [])
        try Validator.validate(provider)
    }

    @Test("Accepts exactly 64 char provider name")
    func testProviderName64Chars() throws {
        let provider = ProviderDefinition(
            name: String(repeating: "a", count: 64),
            stability: nil,
            probes: []
        )
        try Validator.validate(provider)
    }

    @Test("Rejects 65 char provider name")
    func testProviderName65Chars() {
        let provider = ProviderDefinition(
            name: String(repeating: "a", count: 65),
            stability: nil,
            probes: []
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects provider name with hyphen")
    func testProviderNameHyphen() {
        let provider = ProviderDefinition(name: "my-app", stability: nil, probes: [])
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects provider name with space")
    func testProviderNameSpace() {
        let provider = ProviderDefinition(name: "my app", stability: nil, probes: [])
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Accepts underscore in provider name")
    func testProviderNameUnderscore() throws {
        let provider = ProviderDefinition(name: "my_app", stability: nil, probes: [])
        try Validator.validate(provider)
    }

    @Test("Accepts exactly 64 char probe name")
    func testProbeName64Chars() throws {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: String(repeating: "b", count: 64), args: nil, docs: nil)]
        )
        try Validator.validate(provider)
    }

    @Test("Rejects 65 char probe name")
    func testProbeName65Chars() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: String(repeating: "b", count: 65), args: nil, docs: nil)]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects probe name with hyphen")
    func testProbeNameHyphen() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "request-start", args: nil, docs: nil)]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Accepts exactly 10 arguments")
    func testExactly10Args() throws {
        let args = (0..<10).map { ProbeArgument(name: "arg\($0)", type: "Int32") }
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "test", args: args, docs: nil)]
        )
        try Validator.validate(provider)
    }

    @Test("Rejects 11 arguments")
    func test11Args() {
        let args = (0..<11).map { ProbeArgument(name: "arg\($0)", type: "Int32") }
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "test", args: args, docs: nil)]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects invalid argument type")
    func testInvalidType() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(
                name: "test",
                args: [ProbeArgument(name: "x", type: "Float")],
                docs: nil
            )]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Accepts all valid types")
    func testAllValidTypes() throws {
        for type in Constraints.validTypes {
            let provider = ProviderDefinition(
                name: "myapp",
                stability: nil,
                probes: [ProbeDefinition(
                    name: "test",
                    args: [ProbeArgument(name: "x", type: type)],
                    docs: nil
                )]
            )
            try Validator.validate(provider)
        }
    }

    // Names starting with digits

    @Test("Rejects provider name starting with digit")
    func testProviderNameStartsWithDigit() {
        let provider = ProviderDefinition(name: "1app", stability: nil, probes: [])
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects probe name starting with digit")
    func testProbeNameStartsWithDigit() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "123start", args: nil, docs: nil)]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Accepts name starting with underscore")
    func testNameStartsWithUnderscore() throws {
        let provider = ProviderDefinition(
            name: "_myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "_start", args: nil, docs: nil)]
        )
        try Validator.validate(provider)
    }

    // Empty names

    @Test("Rejects empty provider name")
    func testEmptyProviderName() {
        let provider = ProviderDefinition(name: "", stability: nil, probes: [])
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects empty probe name")
    func testEmptyProbeName() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(name: "", args: nil, docs: nil)]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects empty argument name")
    func testEmptyArgName() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(
                name: "test",
                args: [ProbeArgument(name: "", type: "Int32")],
                docs: nil
            )]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    // Stability validation

    @Test("Accepts all valid stabilities")
    func testValidStabilities() throws {
        for stability in Constraints.validStabilities {
            let provider = ProviderDefinition(name: "myapp", stability: stability, probes: [])
            try Validator.validate(provider)
        }
    }

    @Test("Rejects invalid stability")
    func testInvalidStability() {
        let provider = ProviderDefinition(name: "myapp", stability: "garbage", probes: [])
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    // Duplicate detection

    @Test("Rejects duplicate probe names")
    func testDuplicateProbeNames() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [
                ProbeDefinition(name: "start", args: nil, docs: nil),
                ProbeDefinition(name: "start", args: nil, docs: nil)
            ]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects duplicate argument names")
    func testDuplicateArgNames() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(
                name: "test",
                args: [
                    ProbeArgument(name: "x", type: "Int32"),
                    ProbeArgument(name: "x", type: "Int64")
                ],
                docs: nil
            )]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    // Swift keyword collision

    @Test("Rejects Swift keyword as argument name")
    func testSwiftKeywordArg() {
        let provider = ProviderDefinition(
            name: "myapp",
            stability: nil,
            probes: [ProbeDefinition(
                name: "test",
                args: [ProbeArgument(name: "return", type: "Int32")],
                docs: nil
            )]
        )
        #expect(throws: GeneratorError.self) {
            try Validator.validate(provider)
        }
    }

    @Test("Rejects common Swift keywords")
    func testCommonSwiftKeywords() {
        let keywords = ["let", "var", "func", "class", "if", "else", "for", "while", "return", "self"]
        for keyword in keywords {
            let provider = ProviderDefinition(
                name: "myapp",
                stability: nil,
                probes: [ProbeDefinition(
                    name: "test",
                    args: [ProbeArgument(name: keyword, type: "Int32")],
                    docs: nil
                )]
            )
            #expect(throws: GeneratorError.self, "Expected '\(keyword)' to be rejected") {
                try Validator.validate(provider)
            }
        }
    }
}

// MARK: - Generator Tests

@Suite("Generator Tests")
struct GeneratorTests {

    // Swift code generation

    @Test("Generates Swift enum with PascalCase + Probes suffix")
    func testSwiftEnumName() {
        let provider = ProviderDefinition(name: "demo", stability: nil, probes: [])
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("public enum DemoProbes"))
    }

    @Test("Converts underscore name to PascalCase")
    func testSwiftEnumNameUnderscore() {
        let provider = ProviderDefinition(name: "my_app", stability: nil, probes: [])
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("public enum MyAppProbes"))
    }

    @Test("Does not import Foundation in generated code")
    func testNoFoundationImport() {
        let provider = ProviderDefinition(name: "demo", stability: nil, probes: [])
        let code = Generator.generateSwift(for: provider)
        #expect(!code.contains("import Foundation"))
    }

    @Test("Generates Swift function for probe without args")
    func testSwiftProbeNoArgs() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: nil)]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("public static func start()"))
        #expect(code.contains("__dtraceenabled_demo___start"))
        #expect(code.contains("__dtrace_demo___start()"))
    }

    @Test("Generates Swift function with integer argument")
    func testSwiftIntArg() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(
                name: "count",
                args: [ProbeArgument(name: "n", type: "Int32")],
                docs: nil
            )]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("n: @autoclosure () -> Int32"))
        #expect(code.contains("UInt(truncatingIfNeeded: _n)"))
    }

    @Test("Generates Swift function with String argument using withCString")
    func testSwiftStringArg() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(
                name: "log",
                args: [ProbeArgument(name: "msg", type: "String")],
                docs: nil
            )]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("msg: @autoclosure () -> String"))
        #expect(code.contains("_msg.withCString"))
        #expect(code.contains("UInt(bitPattern: _p0)"))
    }

    @Test("Generates Swift with multiple String args (nested withCString)")
    func testSwiftMultipleStrings() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(
                name: "log",
                args: [
                    ProbeArgument(name: "msg1", type: "String"),
                    ProbeArgument(name: "msg2", type: "String")
                ],
                docs: nil
            )]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("_msg1.withCString { _p0 in"))
        #expect(code.contains("_msg2.withCString { _p1 in"))
        #expect(code.contains("UInt(bitPattern: _p0)"))
        #expect(code.contains("UInt(bitPattern: _p1)"))
    }

    @Test("Generates Swift doc comment from docs field")
    func testSwiftDocComment() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: "Fires on start")]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("/// Fires on start"))
    }

    @Test("Converts underscore probe name to camelCase")
    func testSwiftCamelCase() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "request_start", args: nil, docs: nil)]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("func requestStart()"))
    }

    @Test("Generates IS-ENABLED guard")
    func testSwiftIsEnabled() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: nil)]
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("guard __dtraceenabled_demo___start() else { return }"))
    }

    @Test("Includes stability in Swift header comment")
    func testSwiftStabilityComment() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: "Stable",
            probes: []
        )
        let code = Generator.generateSwift(for: provider)
        #expect(code.contains("Stability: Stable"))
    }

    // DTrace provider generation

    @Test("Generates DTrace provider block")
    func testDTraceProvider() {
        let provider = ProviderDefinition(name: "demo", stability: nil, probes: [])
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("provider demo {"))
        #expect(code.contains("};"))
    }

    @Test("Generates DTrace probe without args")
    func testDTraceProbeNoArgs() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: nil)]
        )
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("probe start();"))
    }

    @Test("Generates DTrace probe with C type mapping")
    func testDTraceTypeMapping() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(
                name: "test",
                args: [
                    ProbeArgument(name: "a", type: "Int32"),
                    ProbeArgument(name: "b", type: "String")
                ],
                docs: nil
            )]
        )
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("probe test(int32_t a, char * b);"))
    }

    @Test("Maps all Swift types to C types correctly")
    func testAllTypeMappings() {
        let typeMappings: [(String, String)] = [
            ("Int8", "int8_t"),
            ("Int16", "int16_t"),
            ("Int32", "int32_t"),
            ("Int64", "int64_t"),
            ("Int", "int64_t"),
            ("UInt8", "uint8_t"),
            ("UInt16", "uint16_t"),
            ("UInt32", "uint32_t"),
            ("UInt64", "uint64_t"),
            ("UInt", "uint64_t"),
            ("Bool", "int32_t"),
            ("String", "char *")
        ]
        for (swift, c) in typeMappings {
            let provider = ProviderDefinition(
                name: "demo",
                stability: nil,
                probes: [ProbeDefinition(
                    name: "test",
                    args: [ProbeArgument(name: "x", type: swift)],
                    docs: nil
                )]
            )
            let code = Generator.generateDTrace(for: provider)
            #expect(code.contains("\(c) x"), "Expected \(c) for Swift type \(swift)")
        }
    }

    @Test("Converts underscore to double underscore in DTrace probe")
    func testDTraceUnderscoreConversion() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "request_start", args: nil, docs: nil)]
        )
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("probe request__start();"))
    }

    @Test("Generates DTrace doc comment")
    func testDTraceDocComment() {
        let provider = ProviderDefinition(
            name: "demo",
            stability: nil,
            probes: [ProbeDefinition(name: "start", args: nil, docs: "Fires on start")]
        )
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("/* Fires on start */"))
    }

    @Test("Generates DTrace stability pragmas")
    func testDTraceStabilityPragmas() {
        let provider = ProviderDefinition(name: "demo", stability: "Stable", probes: [])
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("#pragma D attributes Stable/Stable/Common provider demo provider"))
        #expect(code.contains("#pragma D attributes Stable/Stable/Common provider demo args"))
    }

    @Test("Uses Evolving as default stability")
    func testDTraceDefaultStability() {
        let provider = ProviderDefinition(name: "demo", stability: nil, probes: [])
        let code = Generator.generateDTrace(for: provider)
        #expect(code.contains("#pragma D attributes Evolving/Evolving/Common"))
    }
}

// MARK: - Error Tests

@Suite("Error Tests")
struct ErrorTests {

    @Test("fileNotFound includes path in description")
    func testFileNotFoundDescription() {
        let error = GeneratorError.fileNotFound("/path/to/file.dprobes")
        #expect(error.description.contains("/path/to/file.dprobes"))
    }

    @Test("directoryNotFound includes path in description")
    func testDirectoryNotFoundDescription() {
        let error = GeneratorError.directoryNotFound("/path/to/dir")
        #expect(error.description.contains("/path/to/dir"))
    }

    @Test("invalidInput includes message in description")
    func testInvalidInputDescription() {
        let error = GeneratorError.invalidInput("expected object")
        #expect(error.description.contains("expected object"))
    }

    @Test("missingProviderName has meaningful description")
    func testMissingProviderNameDescription() {
        let error = GeneratorError.missingProviderName
        #expect(error.description.contains("name"))
    }

    @Test("validationFailed includes reason in description")
    func testValidationFailedDescription() {
        let error = GeneratorError.validationFailed("too many args")
        #expect(error.description.contains("too many args"))
    }
}
