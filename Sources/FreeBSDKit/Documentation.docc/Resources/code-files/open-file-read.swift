import Capabilities
import Descriptors

// Open a file for reading
let file = try FileCapability.open(
    path: "/etc/passwd",
    flags: .readOnly
)

// Read the entire file
var contents = Data()
while true {
    let chunk = try file.read(count: 4096)
    if chunk.isEmpty { break }
    contents.append(chunk)
}

print(String(data: contents, encoding: .utf8)!)
