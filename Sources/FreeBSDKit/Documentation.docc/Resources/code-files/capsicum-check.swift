import Capsicum

// Check if we're already in capability mode
if Capsicum.isInCapabilityMode {
    print("Already sandboxed!")
} else {
    print("Not in capability mode - can enter sandbox")
}

// Check if Capsicum is supported (FreeBSD)
#if os(FreeBSD)
print("Capsicum is available")
#else
print("Capsicum is not available on this platform")
#endif
