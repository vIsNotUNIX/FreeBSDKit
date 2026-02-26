import Capsicum
import Capabilities
import Descriptors
import Glibc

// After entering capability mode, verify restrictions

try Capsicum.enterCapabilityMode()

// Try to open a file with absolute path - should fail
do {
    let file = try FileCapability.open(path: "/etc/passwd", flags: .readOnly)
    print("ERROR: Should not have succeeded!")
} catch let error as BSDError {
    if error.errno == ECAPMODE {
        print("GOOD: Filesystem access blocked (ECAPMODE)")
    } else if error.errno == ENOTCAPABLE {
        print("GOOD: Capability violation (ENOTCAPABLE)")
    }
}

// Try to create a new socket - should fail
do {
    let socket = try SocketCapability.socket(
        domain: .inet,
        type: .stream,
        protocol: .tcp
    )
    print("ERROR: Should not have succeeded!")
} catch let error as BSDError {
    if error.errno == ECAPMODE {
        print("GOOD: Socket creation blocked (ECAPMODE)")
    }
}

print("Capsicum sandbox is working correctly!")
