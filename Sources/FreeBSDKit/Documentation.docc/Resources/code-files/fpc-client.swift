import FPC
import Foundation

// Connect to the server
let endpoint = try FPCClient.connect(path: "/tmp/myapp.sock")

// Start the endpoint
await endpoint.start()

// Send a message
let request = FPCMessage(payload: Data("Hello, server!".utf8))
try await endpoint.send(request)

// Receive response
let response = try await endpoint.receive()
print("Server replied: \(String(data: response.payload, encoding: .utf8)!)")
