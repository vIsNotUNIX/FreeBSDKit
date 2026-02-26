import Capabilities
import Descriptors
import Foundation

// Descriptor passing uses SCM_RIGHTS control messages
// FreeBSDKit wraps this in a clean API

// Send descriptors
func sendFiles(socket: borrowing SocketCapability, files: [FileCapability]) throws {
    // Convert to opaque references for sending
    let refs = files.map { $0.toOpaqueRef() }

    // Send with optional payload data
    try socket.sendDescriptors(refs, payload: Data("files".utf8))
}

// Receive descriptors
func receiveFiles(socket: borrowing SocketCapability) throws -> [OpaqueDescriptorRef] {
    let (payload, descriptors) = try socket.recvDescriptors(
        maxDescriptors: 8,
        bufferSize: 256
    )

    print("Received \(descriptors.count) descriptors")
    print("Payload: \(String(data: payload, encoding: .utf8) ?? "")")

    return descriptors
}
