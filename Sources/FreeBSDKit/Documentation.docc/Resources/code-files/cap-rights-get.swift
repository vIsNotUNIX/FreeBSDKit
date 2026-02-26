import Capsicum
import Capabilities
import Descriptors

let file = try FileCapability.open(
    path: "/tmp/test.txt",
    flags: [.readWrite, .create],
    mode: 0o644
)

// Get current rights
let rights = try file.getRights()

print("Current rights:")
if rights.contains(.read) { print("  - CAP_READ") }
if rights.contains(.write) { print("  - CAP_WRITE") }
if rights.contains(.seek) { print("  - CAP_SEEK") }
if rights.contains(.fstat) { print("  - CAP_FSTAT") }
if rights.contains(.ftruncate) { print("  - CAP_FTRUNCATE") }
if rights.contains(.fsync) { print("  - CAP_FSYNC") }
if rights.contains(.mmap) { print("  - CAP_MMAP") }

// Limit rights
try file.limitRights(to: [.read, .fstat])

// Check rights again
let newRights = try file.getRights()
print("\nAfter limiting:")
if newRights.contains(.read) { print("  - CAP_READ") }
if newRights.contains(.write) { print("  - CAP_WRITE (should not appear)") }
if newRights.contains(.fstat) { print("  - CAP_FSTAT") }
