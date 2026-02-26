import Capsicum
import Capabilities
import Descriptors

// Open a directory
let dataDir = try DirectoryCapability.open(
    path: "/var/lib/myapp",
    flags: [.readWrite, .directory]
)

// Limit directory to:
// - Look up files
// - Read files
// - Create new files
// - But NOT delete files or create subdirectories
try dataDir.limitRights(to: [
    .lookup,    // Look up files by name
    .read,      // Read directory listing
    .create,    // Create new files
    .fstat,     // Get directory status
    // Notably missing: .unlinkat, .mkdirat
])

// Now files can be opened and created
let file = try FileCapability.open(
    at: dataDir,
    path: "newfile.txt",
    flags: [.writeOnly, .create],
    mode: 0o644
)
try file.write(Data("content".utf8))

// But this would fail:
// try dataDir.unlink(path: "oldfile.txt")  // ENOTCAPABLE
// try dataDir.mkdir(path: "subdir")        // ENOTCAPABLE
