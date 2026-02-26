import Capsicum
import Capabilities
import Descriptors
import FreeBSDKit
import Glibc

/// Handle Capsicum-specific errors appropriately
func performOperation(path: String) throws {
    do {
        let file = try FileCapability.open(path: path, flags: .readOnly)
        // Use file...
    } catch let error as BSDError {
        switch error.errno {
        case ECAPMODE:
            // We're in capability mode and tried an absolute path
            print("Cannot use absolute paths in capability mode")
            print("Use openat() with a directory capability instead")

        case ENOTCAPABLE:
            // We have a capability but it lacks required rights
            print("Capability lacks required rights")
            print("Check cap_rights_limit() settings")

        case EACCES:
            // Standard permission denied
            print("Permission denied")

        case ENOENT:
            // File not found
            print("File not found: \(path)")

        default:
            // Re-throw other errors
            throw error
        }
    }
}

// Example: Checking if we're sandboxed before attempting operations
func safeOpen(path: String) throws -> FileCapability? {
    if Capsicum.isInCapabilityMode {
        print("Warning: Cannot open absolute paths in capability mode")
        return nil
    }
    return try FileCapability.open(path: path, flags: .readOnly)
}
