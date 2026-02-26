import Capabilities
import Descriptors
import Foundation

let file = try FileCapability.open(
    path: "/tmp/output.bin",
    flags: [.writeOnly, .create, .truncate],
    mode: 0o644
)

// Write string data
let text = "Hello, FreeBSD!"
try file.write(Data(text.utf8))

// Write binary data
let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0xFF]
try file.write(Data(bytes))

// Write from a buffer
var buffer = Data(repeating: 0x42, count: 1024)
try file.write(buffer)
