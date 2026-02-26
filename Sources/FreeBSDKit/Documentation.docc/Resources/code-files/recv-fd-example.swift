import Capabilities
import Descriptors
import Foundation

// Accept connection from sender
let server = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)
unlink("/tmp/fd-receiver.sock")
try server.bind(address: try UnixSocketAddress(path: "/tmp/fd-receiver.sock"))
try server.listen()

let client = try server.accept()

// Receive descriptors
let (payload, descriptors) = try client.recvDescriptors(
    maxDescriptors: 8,
    bufferSize: 256
)

let command = String(data: payload, encoding: .utf8) ?? ""
print("Command: \(command)")
print("Received \(descriptors.count) descriptors")

// Use the first descriptor
if let firstFD = descriptors.first {
    // Read from the received file descriptor
    let fd = firstFD.rawValue
    var buffer = [UInt8](repeating: 0, count: 1024)
    let bytesRead = read(fd, &buffer, buffer.count)
    if bytesRead > 0 {
        print("Content: \(String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? "")")
    }
}
