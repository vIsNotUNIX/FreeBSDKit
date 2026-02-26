import FPC
import Foundation

// Create a listener on a Unix socket path
let listener = try FPCListener.listen(on: "/tmp/myapp.sock")

// Start accepting connections
await listener.start()

// Get the stream of incoming connections
let connections = try listener.connections()

// Handle each connection
for try await endpoint in connections {
    // Start the endpoint
    await endpoint.start()

    // Handle messages from this client
    Task {
        for try await message in try endpoint.messages() {
            print("Received: \(message.payload)")

            // Send a response
            try await endpoint.send(FPCMessage(payload: Data("ACK".utf8)))
        }
    }
}
