import Capabilities
import Descriptors
import Foundation

let socket = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)
// ... connect ...

// Open multiple files
let configFile = try FileCapability.open(path: "/etc/myapp.conf", flags: .readOnly)
let dataDir = try DirectoryCapability.open(path: "/var/lib/myapp", flags: [.readOnly, .directory])
let logFile = try FileCapability.open(path: "/var/log/myapp.log", flags: [.writeOnly, .append])

// Send all descriptors in one message
try socket.sendDescriptors(
    [
        configFile.toOpaqueRef(),
        dataDir.toOpaqueRef(),
        logFile.toOpaqueRef()
    ],
    payload: Data("INIT:config,data,log\n".utf8)
)

print("Sent 3 descriptors")
