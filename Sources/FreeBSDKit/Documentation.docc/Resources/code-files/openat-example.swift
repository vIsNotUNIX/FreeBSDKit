import Capabilities
import Descriptors

// Open a base directory
let baseDir = try DirectoryCapability.open(
    path: "/var/log",
    flags: [.readOnly, .directory]
)

// Open a file relative to the directory
// Uses openat(2) under the hood
let logFile = try FileCapability.open(
    at: baseDir,
    path: "messages",  // Relative path
    flags: .readOnly
)

// Read from the log file
let data = try logFile.read(count: 1024)
print(String(data: data, encoding: .utf8) ?? "")

// This pattern is essential for Capsicum:
// 1. Open directory capabilities before entering capability mode
// 2. Use relative paths with openat() after sandboxing
