import Capabilities
import Descriptors
import Foundation

// Open a directory capability BEFORE entering capability mode
let dir = try DirectoryCapability.open(
    path: "/var/run/myapp",
    flags: [.readOnly, .directory]
)

// Create a socket
let server = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)

// Bind relative to the directory
// Uses bindat(2) - works in Capsicum capability mode!
let address = try UnixSocketAddress(path: "control.sock")
try server.bind(at: dir, address: address)

try server.listen(backlog: 5)
print("Server bound to /var/run/myapp/control.sock")

// Now we can enter capability mode and still accept connections
// on this socket
