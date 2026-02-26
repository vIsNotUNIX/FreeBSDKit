import Capsicum
import Capabilities
import Descriptors

// Data directory: read files, but not modify directory structure
let dataDir = try DirectoryCapability.open(
    path: "/var/lib/myapp/data",
    flags: [.readOnly, .directory]
)

// Rights for read-only data directory
try dataDir.limitRights(to: [
    .lookup,    // Look up files by name
    .read,      // Read directory listing
    .fstat,     // Get directory info

    // When opening files, they'll inherit limited rights
])

// List directory
let entries = try dataDir.readDirectory()
for entry in entries {
    print("Found: \(entry.name)")
}

// Open a file from the directory
let dataFile = try FileCapability.open(
    at: dataDir,
    path: "data.json",
    flags: .readOnly
)

// Further limit the opened file
try dataFile.limitRights(to: [.read, .seek, .fstat])

let content = try dataFile.read(count: 10_000)
print("Read \(content.count) bytes from data.json")
