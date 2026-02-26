import FPC
import Capabilities
import Foundation

// Messages can carry both data and file descriptors
struct Request: Codable {
    let command: String
    let path: String
}

// Send a request with JSON payload
let request = Request(command: "OPEN", path: "/etc/passwd")
let data = try JSONEncoder().encode(request)
let message = FPCMessage(payload: data)

try await endpoint.send(message)

// Receive a response with a file descriptor
let response = try await endpoint.receive()

if let fd = response.descriptors.first {
    // Convert to typed capability
    let file = FileCapability(fd.rawValue)
    let content = try file.read(count: 4096)
    print(String(data: content, encoding: .utf8)!)
}
