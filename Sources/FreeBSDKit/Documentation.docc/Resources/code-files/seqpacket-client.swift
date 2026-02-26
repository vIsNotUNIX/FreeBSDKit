import Capabilities
import Descriptors
import Foundation

let socket = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)

let address = try UnixSocketAddress(path: "/tmp/seqpacket.sock")
try socket.connect(address: address)

// Send individual messages - boundaries are preserved
let messages = ["Hello", "World", "From", "Client"]

for msg in messages {
    try socket.write(Data(msg.utf8))

    // Read the acknowledgment
    let ack = try socket.read(count: 4096)
    print("Server: \(String(data: ack, encoding: .utf8) ?? "")")
}

// Shutdown to signal we're done
try socket.shutdown(how: .write)
