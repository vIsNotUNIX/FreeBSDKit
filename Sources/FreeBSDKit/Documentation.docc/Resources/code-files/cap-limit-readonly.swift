import Capsicum
import Capabilities
import Descriptors

// Open a file with full access
let file = try FileCapability.open(
    path: "/etc/myapp.conf",
    flags: .readWrite  // Open with read/write
)

// Limit to read-only
// After this, writes will fail with ENOTCAPABLE
try file.limitRights(to: [.read, .seek, .fstat])

// This works
let data = try file.read(count: 1024)
print("Read \(data.count) bytes")

// This would fail with ENOTCAPABLE
// try file.write(Data("test".utf8))

// Now enter capability mode
try Capsicum.enterCapabilityMode()

// File is still usable for reading
let moreData = try file.read(count: 1024)
