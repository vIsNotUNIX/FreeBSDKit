import Capabilities
import Descriptors
import Foundation

// Create a Unix domain STREAM socket
let server = try SocketCapability.socket(
    domain: .unix,
    type: [.stream, .cloexec],
    protocol: .default
)

// Remove any existing socket file
unlink("/tmp/example.sock")

// Bind to a path
let address = try UnixSocketAddress(path: "/tmp/example.sock")
try server.bind(address: address)

// Listen for connections
try server.listen(backlog: 5)
print("Server listening on /tmp/example.sock")

// Accept a connection
let client = try server.accept()
print("Client connected!")

// Read data from client
let data = try client.read(count: 1024)
print("Received: \(String(data: data, encoding: .utf8) ?? "")")

// Send response
try client.write(Data("Hello from server!\n".utf8))
