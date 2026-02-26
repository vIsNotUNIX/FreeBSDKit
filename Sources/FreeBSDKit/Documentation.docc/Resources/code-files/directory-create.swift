import Capabilities
import Descriptors

// Open a base directory
let baseDir = try DirectoryCapability.open(
    path: "/tmp",
    flags: [.readOnly, .directory]
)

// Create a subdirectory relative to base
try baseDir.mkdir(path: "myapp", mode: 0o755)

// Create a file in the subdirectory
let file = try FileCapability.open(
    at: baseDir,
    path: "myapp/config.txt",
    flags: [.writeOnly, .create],
    mode: 0o644
)

try file.write(Data("key=value\n".utf8))
