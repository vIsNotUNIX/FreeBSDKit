import Capabilities
import Descriptors
import Foundation

// Receive descriptors
let (payload, descriptors) = try socket.recvDescriptors(
    maxDescriptors: 8,
    bufferSize: 256
)

// Parse the payload to understand what types we received
let command = String(data: payload, encoding: .utf8) ?? ""

// Convert opaque references to typed capabilities
// The sender told us: "INIT:config,data,log"
if command.hasPrefix("INIT:") {
    guard descriptors.count >= 3 else {
        throw BSDError.invalidArgument
    }

    // Convert to typed capabilities
    // Note: These take ownership of the raw FDs
    let configFile = FileCapability(descriptors[0].rawValue)
    let dataDir = DirectoryCapability(descriptors[1].rawValue)
    let logFile = FileCapability(descriptors[2].rawValue)

    // Now use them with full type safety
    let config = try configFile.read(count: 4096)
    print("Config: \(String(data: config, encoding: .utf8) ?? "")")

    // List data directory
    let entries = try dataDir.readDirectory()
    print("Data files: \(entries.map { $0.name })")

    // Write to log
    try logFile.write(Data("Started successfully\n".utf8))
}
