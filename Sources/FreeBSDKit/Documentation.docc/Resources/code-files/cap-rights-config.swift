import Capsicum
import Capabilities
import Descriptors

// Configuration file: read-only, no code execution
let configFile = try FileCapability.open(
    path: "/etc/myapp.conf",
    flags: .readOnly
)

// Minimal rights for a config file
try configFile.limitRights(to: [
    .read,      // Read the file
    .seek,      // Seek to positions (for re-reading)
    .fstat,     // Get file info
    // No .write - can't modify
    // No .mmap with execute - can't run as code
    // No .fchmod - can't change permissions
])

print("Config file secured with read-only rights")
