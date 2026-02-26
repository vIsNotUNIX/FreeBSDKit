import Capabilities
import Descriptors
import Foundation

// Connect to the receiving process
let socket = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)
let address = try UnixSocketAddress(path: "/tmp/fd-receiver.sock")
try socket.connect(address: address)

// Open a file to send
let file = try FileCapability.open(
    path: "/etc/passwd",
    flags: .readOnly
)

// Get an opaque reference for sending
let fileRef = file.toOpaqueRef()

// Send the descriptor with a command payload
try socket.sendDescriptors(
    [fileRef],
    payload: Data("READ_FILE\n".utf8)
)

print("Sent file descriptor to receiver")
