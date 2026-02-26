import Capabilities
import Descriptors
import Foundation

// Open a directory capability
let dir = try DirectoryCapability.open(
    path: "/var/run/myapp",
    flags: [.readOnly, .directory]
)

// Create a socket
let socket = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)

// Connect relative to the directory
// Uses connectat(2) - works in Capsicum capability mode!
let address = try UnixSocketAddress(path: "control.sock")
try socket.connect(at: dir, address: address)

print("Connected to /var/run/myapp/control.sock")

// Send a command
try socket.write(Data("STATUS\n".utf8))

// Read response
let response = try socket.read(count: 4096)
print("Response: \(String(data: response, encoding: .utf8) ?? "")")
