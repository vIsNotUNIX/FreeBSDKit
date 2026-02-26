import Capsicum
import Capabilities
import Descriptors

// Open all required files BEFORE entering capability mode

// 1. Open files for reading/writing
let configFile = try FileCapability.open(
    path: "/etc/myapp.conf",
    flags: .readOnly
)

let logFile = try FileCapability.open(
    path: "/var/log/myapp.log",
    flags: [.writeOnly, .append, .create],
    mode: 0o644
)

// 2. Open directories for relative operations
let dataDir = try DirectoryCapability.open(
    path: "/var/lib/myapp",
    flags: [.readOnly, .directory]
)

// 3. Standard file descriptors (stdin, stdout, stderr) remain available

// Now enter capability mode
try Capsicum.enterCapabilityMode()

// After this point:
// - Use configFile, logFile, dataDir through their capabilities
// - Use openat() with dataDir for files in /var/lib/myapp
// - Cannot open files with absolute paths
