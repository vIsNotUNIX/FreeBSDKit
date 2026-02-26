import Capabilities
import Descriptors
import Foundation

let file = try FileCapability.open(
    path: "/tmp/data.bin",
    flags: .readOnly
)

// Read a specific number of bytes
let header = try file.read(count: 16)
print("Header: \(header.map { String(format: "%02x", $0) }.joined())")

// Read until EOF
var allData = Data()
while true {
    let chunk = try file.read(count: 8192)
    if chunk.isEmpty {
        break  // EOF
    }
    allData.append(chunk)
}
print("Total size: \(allData.count) bytes")
