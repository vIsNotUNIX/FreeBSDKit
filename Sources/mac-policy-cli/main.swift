import Foundation
import ArgumentParser
import MacLabel
import Glibc
import Capabilities
import Capsicum

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
            """,
        version: "1.0.0",
        subcommands: [Validate.self, Apply.self, Verify.self, Remove.self, Show.self],
        defaultSubcommand: nil
    )
}

struct CommonOptions: ParsableArguments {
    @Argument(help: "Path to the JSON configuration file")
    var configFile: String

    @Flag(name: .shortAndLong, help: "Print detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Output results in JSON format")
    var json: Bool = false
}

// MARK: - Helper Functions

/// Loads a configuration file using a Capsicum-restricted file capability.
///
/// ## Security Model
///
/// This function implements defense-in-depth by:
/// 1. Opening the file with minimal flags (O_RDONLY | O_CLOEXEC)
/// 2. Wrapping the descriptor in a FileCapability
/// 3. Restricting rights to the absolute minimum needed (.read, .fstat, .seek)
/// 4. Using the Descriptor API for all file operations
///
/// **Rights Restriction**: The descriptor is limited to:
/// - `.read` - Read file contents
/// - `.fstat` - Get file metadata (required for size check)
/// - `.seek` - Position seeking (needed by readExact())
///
/// Even if the configuration parsing code is exploited, the attacker cannot:
/// - Write to the config file
/// - Open other files
/// - Execute operations not granted by these rights
///
/// ## Capsicum Lifecycle
///
/// **BEFORE Capability Mode**:
/// - This function can be called normally
/// - `open()` by path works
/// - Filesystem namespace is available
///
/// **AFTER Capability Mode** (if this tool were to enter it):
/// - `open()` by path would fail (no ambient authority)
/// - Must pass pre-opened file descriptors
/// - Only operations on existing descriptors are allowed
///
/// ## TOCTOU Protection
///
/// By opening the file once and passing the descriptor:
/// - Validates and reads the *same* file
/// - Prevents race conditions where file is replaced between checks
/// - Capsicum rights ensure descriptor properties can't change
///
/// - Parameter path: Path to configuration file to load
/// - Returns: Validated and parsed configuration
/// - Throws: LabelError if file cannot be opened, read, or parsed
func loadConfiguration(path: String) throws -> LabelConfiguration<FileLabel> {
    // Open file (requires filesystem namespace - must be before capability mode)
    let rawFd = path.withCString { cPath in
        open(cPath, O_RDONLY | O_CLOEXEC)
    }

    guard rawFd >= 0 else {
        throw LabelError.invalidConfiguration("Cannot open configuration file: \(String(cString: strerror(errno)))")
    }

    // Wrap in FileCapability for Capsicum protection
    let capability = FileCapability(rawFd)

    // Restrict to minimal rights needed for reading config
    // This is enforced at the kernel level by Capsicum
    let rights = CapsicumRightSet(rights: [
        .read,      // Read file contents
        .fstat,     // Get file metadata
        .seek       // Position seeking for readExact()
    ])

    _ = capability.limit(rights: rights)

    // Load configuration using restricted capability
    // All file operations go through the Descriptor API
    do {
        let config = try LabelConfiguration<FileLabel>.load(from: capability)
        capability.close()
        return config
    } catch {
        capability.close()
        throw error
    }
}

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

            let labeler = Labeler(configuration: config)

            if options.verbose && !options.json {
                print("Validating all paths...")
            }

            do {
                try labeler.validateAll()

                if options.json {
                    let output = ValidateOutput(
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
                    let output = ValidateOutput(
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
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json
            labeler.overwriteExisting = !noOverwrite

            let results = try labeler.apply()
            let failures = results.filter { !$0.success }

            if options.json {
                let output = ApplyOutput(results: results)
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
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json

            let results = try labeler.remove()
            let failures = results.filter { !$0.success }

            if options.json {
                let output = ApplyOutput(results: results)  // Reuse structure
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
                print()
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = false  // Don't use verbose for show

            let results = try labeler.show()

            if options.json {
                let output = ShowOutput(results: results)
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
                print()
            }

            var labeler = Labeler(configuration: config)
            labeler.verbose = options.verbose && !options.json

            let results = try labeler.verify()
            let mismatches = results.filter { !$0.matches }

            if options.json {
                let output = VerifyOutput(results: results)
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
