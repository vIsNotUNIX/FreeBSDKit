import Capabilities
import Descriptors
import Foundation

// SEQPACKET preserves message boundaries
let server = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)

unlink("/tmp/seqpacket.sock")
let address = try UnixSocketAddress(path: "/tmp/seqpacket.sock")
try server.bind(address: address)
try server.listen(backlog: 5)

print("SEQPACKET server listening...")

let client = try server.accept()

// Each recv() returns exactly one message
// Message boundaries are preserved!
while true {
    let message = try client.read(count: 4096)
    if message.isEmpty { break }

    let text = String(data: message, encoding: .utf8) ?? ""
    print("Message: \(text)")

    // Send a reply (as a complete message)
    try client.write(Data("ACK: \(text)".utf8))
}
