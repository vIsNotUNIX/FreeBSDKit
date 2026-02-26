import Capsicum
import Capabilities
import Descriptors
import Foundation

/// A file processor that sandboxes itself after initialization.
struct SandboxedProcessor {
    let inputDir: DirectoryCapability
    let outputDir: DirectoryCapability
    let logFile: FileCapability

    /// Initialize with paths, then enter sandbox.
    static func create(
        inputPath: String,
        outputPath: String,
        logPath: String
    ) throws -> SandboxedProcessor {
        // Open all resources before sandboxing
        let inputDir = try DirectoryCapability.open(
            path: inputPath,
            flags: [.readOnly, .directory]
        )

        let outputDir = try DirectoryCapability.open(
            path: outputPath,
            flags: [.readWrite, .directory]
        )

        let logFile = try FileCapability.open(
            path: logPath,
            flags: [.writeOnly, .append, .create],
            mode: 0o644
        )

        // Enter capability mode
        try Capsicum.enterCapabilityMode()

        return SandboxedProcessor(
            inputDir: inputDir,
            outputDir: outputDir,
            logFile: logFile
        )
    }

    /// Process files from input directory to output directory.
    func processFiles() throws {
        // List input directory
        let entries = try inputDir.readDirectory()

        for entry in entries where entry.type == .regular {
            try log("Processing: \(entry.name)")

            // Open input file (relative to inputDir)
            let input = try FileCapability.open(
                at: inputDir,
                path: entry.name,
                flags: .readOnly
            )

            // Read and process content
            let data = try input.read(count: 1_000_000)
            let processed = processData(data)

            // Write to output directory
            let output = try FileCapability.open(
                at: outputDir,
                path: entry.name + ".out",
                flags: [.writeOnly, .create, .truncate],
                mode: 0o644
            )
            try output.write(processed)

            try log("Completed: \(entry.name)")
        }
    }

    private func processData(_ data: Data) -> Data {
        // Your processing logic here
        return data.reversed() as Data
    }

    private func log(_ message: String) throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try logFile.write(Data("[\(timestamp)] \(message)\n".utf8))
    }
}

// Usage
let processor = try SandboxedProcessor.create(
    inputPath: "/var/spool/myapp/input",
    outputPath: "/var/spool/myapp/output",
    logPath: "/var/log/myapp.log"
)
try processor.processFiles()
