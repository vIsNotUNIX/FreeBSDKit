/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import ArgumentParser
import MacLabel
import Glibc
import Capabilities
import Capsicum

// MARK: - Root Command

struct MacLabelCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maclabel",
        abstract: "Apply and manage MACF security labels on files",
        discussion: """
            The maclabel tool applies security labels to binaries and files using
            FreeBSD extended attributes. Labels are stored in the system namespace
            and can be read by MACF (Mandatory Access Control Framework) policies.

            Labels are stored as newline-separated key=value pairs in the
            extended attribute specified in the configuration file.

            By default, all operations use Capsicum for defense-in-depth security,
            providing kernel-enforced restrictions and TOCTOU protection.
            """,
        version: "1.0.0",
        subcommands: [Validate.self, Apply.self, Verify.self, Remove.self, Show.self],
        defaultSubcommand: nil
    )
}

// MARK: - Common Options

struct CommonOptions: ParsableArguments {
    @Argument(help: "Path to the JSON configuration file")
    var configFile: String

    @Flag(name: .shortAndLong, help: "Print detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Output results in JSON format")
    var json: Bool = false

    @Flag(name: .long, help: "Disable Capsicum (use path-based operations)")
    var noCapsicum: Bool = false
}

// MARK: - Helper Functions

/// Loads a configuration file using a Capsicum-restricted file capability.
func loadConfiguration(path: String) throws -> LabelConfiguration<FileLabel> {
    let rawFd = path.withCString { cPath in
        open(cPath, O_RDONLY | O_CLOEXEC)
    }

    guard rawFd >= 0 else {
        throw LabelError.invalidConfiguration("Cannot open configuration file: \(String(cString: strerror(errno)))")
    }

    let capability = FileCapability(rawFd)

    let rights = CapsicumRightSet(rights: [
        .read,
        .fstat,
        .seek
    ])

    _ = capability.limit(rights: rights)

    do {
        let config = try LabelConfiguration<FileLabel>.load(from: capability)
        capability.close()
        return config
    } catch {
        capability.close()
        throw error
    }
}

// MARK: - Validate Command

extension MacLabelCLI {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate configuration file and check all paths exist"
        )

        @OptionGroup var options: CommonOptions

        func run() throws {
            let config = try loadConfiguration(path: options.configFile)

            if options.verbose && !options.json {
                print("Loaded \(config.labels.count) label(s)")
                print("Using attribute name: \(config.attributeName)")
            }

            var labeler = Labeler(configuration: config)
            labeler.useCapsicum = !options.noCapsicum

            if options.verbose && !options.json {
                print("Validating configuration...")
            }

            do {
                try labeler.validateConfiguration()

                if options.json {
                    let output = ValidationSummary(
                        success: true,
                        totalFiles: config.labels.count,
                        attributeName: config.attributeName
                    )
                    try printJSON(output)
                } else {
                    print("✓ All \(config.labels.count) file(s) exist")
                    print("✓ Configuration is valid")
                }
            } catch {
                if options.json {
                    let output = ValidationSummary(
                        success: false,
                        totalFiles: config.labels.count,
                        attributeName: config.attributeName,
                        error: error.localizedDescription
                    )
                    try printJSON(output)
                } else if options.verbose {
                    print("✗ Validation failed: \(error.localizedDescription)")
                }
                throw error
            }
        }
    }
}

// MARK: - Apply Command

extension MacLabelCLI {
    struct Apply: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Apply labels from configuration file to files",
            discussion: """
                Applies security labels to all files specified in the configuration.
                All file paths are validated before applying any labels to ensure
                consistency. If even one file is missing, the operation fails.
                """
        )

        @OptionGroup var options: CommonOptions

        @Flag(name: .long, help: "Don't overwrite existing labels")
        var noOverwrite: Bool = false

        func run() throws {
            let config = try loadConfiguration(path: options.configFile)

            if options.verbose && !options.json {
                print("Loaded \(config.labels.count) label(s)")
                print("Using attribute name: \(config.attributeName)")
                if !options.noCapsicum {
                    print("Using Capsicum for defense-in-depth")
                }
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json
            labeler.overwriteExisting = !noOverwrite
            labeler.useCapsicum = !options.noCapsicum

            let results = try labeler.apply()
            let failures = results.filter { !$0.success }

            if options.json {
                let output = OperationSummary(results: results)
                try printJSON(output)
                if !failures.isEmpty {
                    throw ExitCode.failure
                }
            } else {
                if failures.isEmpty {
                    print("✓ Successfully labeled \(results.count) file(s)")
                } else {
                    print("✗ Failed to label \(failures.count) of \(results.count) file(s):")
                    for failure in failures {
                        if let error = failure.error {
                            print("  - \(failure.path): \(error.localizedDescription)")
                        } else {
                            print("  - \(failure.path): Failed with unknown error")
                        }
                    }
                    throw ExitCode.failure
                }
            }
        }
    }
}

// MARK: - Remove Command

extension MacLabelCLI {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove labels from files in configuration",
            discussion: """
                Removes security labels from all files specified in the configuration.
                All file paths are validated before removing any labels to ensure
                consistency.
                """
        )

        @OptionGroup var options: CommonOptions

        func run() throws {
            let config = try loadConfiguration(path: options.configFile)

            if options.verbose && !options.json {
                print("Loaded \(config.labels.count) label(s)")
                print("Using attribute name: \(config.attributeName)")
                if !options.noCapsicum {
                    print("Using Capsicum for defense-in-depth")
                }
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json
            labeler.useCapsicum = !options.noCapsicum

            let results = try labeler.remove()
            let failures = results.filter { !$0.success }

            if options.json {
                let output = OperationSummary(results: results)
                try printJSON(output)
                if !failures.isEmpty {
                    throw ExitCode.failure
                }
            } else {
                if failures.isEmpty {
                    print("✓ Successfully removed labels from \(results.count) file(s)")
                } else {
                    print("✗ Failed to remove labels from \(failures.count) of \(results.count) file(s):")
                    for failure in failures {
                        if let error = failure.error {
                            print("  - \(failure.path): \(error.localizedDescription)")
                        } else {
                            print("  - \(failure.path): Failed with unknown error")
                        }
                    }
                    throw ExitCode.failure
                }
            }
        }
    }
}

// MARK: - Show Command

extension MacLabelCLI {
    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display current labels for files in configuration",
            discussion: """
                Shows the current security labels on all files specified in the
                configuration. All file paths are validated first.
                """
        )

        @OptionGroup var options: CommonOptions

        func run() throws {
            let config = try loadConfiguration(path: options.configFile)

            if options.verbose && !options.json {
                print("Loaded \(config.labels.count) label(s)")
                print("Using attribute name: \(config.attributeName)")
                if !options.noCapsicum {
                    print("Using Capsicum for defense-in-depth")
                }
                print()
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = false
            labeler.useCapsicum = !options.noCapsicum

            let results = try labeler.show()

            if options.json {
                let output = LabelsSummary(results: results)
                try printJSON(output)
            } else {
                for (path, labels) in results {
                    print("\(path):")
                    if let labels = labels {
                        if labels.hasPrefix("ERROR:") {
                            print("  \(labels)")
                        } else if labels.isEmpty {
                            print("  (no labels)")
                        } else {
                            for line in labels.split(separator: "\n") {
                                print("  \(line)")
                            }
                        }
                    } else {
                        print("  (no labels)")
                    }
                }
            }
        }
    }
}

// MARK: - Verify Command

extension MacLabelCLI {
    struct Verify: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify that labels are correctly applied to files",
            discussion: """
                Verifies that all files have the exact labels specified in the
                configuration. Reports any mismatches including missing, extra,
                or incorrect attribute values. All file paths are validated first.
                """
        )

        @OptionGroup var options: CommonOptions

        func run() throws {
            let config = try loadConfiguration(path: options.configFile)

            if options.verbose && !options.json {
                print("Loaded \(config.labels.count) label(s)")
                print("Using attribute name: \(config.attributeName)")
                if !options.noCapsicum {
                    print("Using Capsicum for defense-in-depth")
                }
                print()
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json
            labeler.useCapsicum = !options.noCapsicum

            let results = try labeler.verify()
            let mismatches = results.filter { !$0.matches }

            if options.json {
                let output = VerificationSummary(results: results)
                try printJSON(output)
                if !mismatches.isEmpty {
                    throw ExitCode.failure
                }
            } else {
                if mismatches.isEmpty {
                    print("✓ All \(results.count) file(s) have correct labels")
                } else {
                    print("✗ \(mismatches.count) of \(results.count) file(s) have incorrect labels:")
                    print()

                    for result in mismatches {
                        print("\(result.path):")
                        if let error = result.error {
                            print("  Error: \(error.localizedDescription)")
                        } else {
                            for mismatch in result.mismatches {
                                print("  - \(mismatch)")
                            }
                        }
                        print()
                    }

                    throw ExitCode.failure
                }
            }
        }
    }
}

// Run the CLI
MacLabelCLI.main()
