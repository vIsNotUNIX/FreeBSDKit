import Capabilities
import Descriptors

// Open a directory for path-relative operations
let dir = try DirectoryCapability.open(
    path: "/var/log",
    flags: [.readOnly, .directory]
)

// Now we can perform operations relative to this directory
// This is the foundation for Capsicum sandboxing

// The directory descriptor can be used with openat, fstatat, etc.
