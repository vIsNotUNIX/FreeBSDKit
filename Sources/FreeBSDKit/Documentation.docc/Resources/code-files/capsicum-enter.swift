import Capsicum

// Enter capability mode
// This is IRREVERSIBLE for the lifetime of the process!
do {
    try Capsicum.enterCapabilityMode()
    print("Successfully entered capability mode")
} catch {
    print("Failed to enter capability mode: \(error)")
}

// Verify we're sandboxed
assert(Capsicum.isInCapabilityMode)

// Now these operations will fail:
// - open("/etc/passwd", O_RDONLY)  -> ECAPMODE
// - socket(AF_INET, SOCK_STREAM, 0) -> ECAPMODE
// - connect() to new addresses -> ECAPMODE
// - kill() arbitrary processes -> ECAPMODE
