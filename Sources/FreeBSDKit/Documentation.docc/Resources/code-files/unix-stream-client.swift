import Capabilities
import Descriptors
import Foundation

// Create a Unix domain STREAM socket
let socket = try SocketCapability.socket(
    domain: .unix,
    type: [.stream, .cloexec],
    protocol: .default
)

// Connect to the server
let address = try UnixSocketAddress(path: "/tmp/example.sock")
try socket.connect(address: address)
print("Connected to server!")

// Send a message
try socket.write(Data("Hello from client!\n".utf8))

// Read response
let response = try socket.read(count: 1024)
print("Server said: \(String(data: response, encoding: .utf8) ?? "")")
