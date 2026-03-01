/*
 * dprobes-cli - Command Line Interface
 *
 * Generates Swift probe code and DTrace provider definitions from
 * a JSON probe specification file (.dprobes).
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

import ArgumentParser
import Foundation

@main
struct DProbesCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dprobes",
        abstract: "Generate Swift probe code from .dprobes definitions",
        discussion: """
            Generates Swift probe functions and DTrace provider definitions
            from a JSON probe specification file.

            Example .dprobes file:
            {
              "name": "myapp",
              "stability": "Evolving",
              "probes": [
                {
                  "name": "request_start",
                  "docs": "Fires when request begins",
                  "args": [
                    { "name": "path", "type": "String" },
                    { "name": "method", "type": "Int32" }
                  ]
                }
              ]
            }

            Supported types: Int8, Int16, Int32, Int64, Int,
                             UInt8, UInt16, UInt32, UInt64, UInt,
                             Bool, String
            """,
        version: "1.0.0"
    )

    @Argument(help: "Input .dprobes file")
    var input: String

    @Option(name: .shortAndLong, help: "Output directory")
    var outputDir: String = "."

    @Flag(name: .long, help: "Generate only Swift code")
    var swiftOnly: Bool = false

    @Flag(name: .long, help: "Generate only DTrace provider")
    var dtraceOnly: Bool = false

    func validate() throws {
        if swiftOnly && dtraceOnly {
            throw ValidationError("Cannot specify both --swift-only and --dtrace-only")
        }
    }

    func run() throws {
        guard let content = try? String(contentsOfFile: input, encoding: .utf8) else {
            throw GeneratorError.fileNotFound(input)
        }

        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: outputDir, isDirectory: &isDir) || !isDir.boolValue {
            throw GeneratorError.directoryNotFound(outputDir)
        }

        let provider = try Parser.parse(content)
        try Validator.validate(provider)

        if !dtraceOnly {
            let swiftCode = Generator.generateSwift(for: provider)
            let swiftPath = "\(outputDir)/\(provider.name)_probes.swift"
            try swiftCode.write(toFile: swiftPath, atomically: true, encoding: .utf8)
            print("Generated: \(swiftPath)")
        }

        if !swiftOnly {
            let dCode = Generator.generateDTrace(for: provider)
            let dPath = "\(outputDir)/\(provider.name)_provider.d"
            try dCode.write(toFile: dPath, atomically: true, encoding: .utf8)
            print("Generated: \(dPath)")
        }

        if !swiftOnly && !dtraceOnly {
            print("""

                Next steps:
                  1. Add \(provider.name)_probes.swift to your project
                  2. Compile the provider:
                     dtrace -G -s \(outputDir)/\(provider.name)_provider.d <your_object_files>.o -o \(provider.name)_provider.o
                  3. Link \(provider.name)_provider.o with your binary
                """)
        }
    }
}
