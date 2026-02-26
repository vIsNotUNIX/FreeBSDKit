import Capsicum
import Capabilities
import Descriptors

// Create sockets BEFORE entering capability mode

// 1. Create a listening socket
let listener = try SocketCapability.socket(
    domain: .unix,
    type: [.seqpacket, .cloexec],
    protocol: .default
)
try listener.bind(address: UnixSocketAddress(path: "/var/run/myapp.sock"))
try listener.listen()

// 2. Connect to a remote service
let remoteSocket = try SocketCapability.socket(
    domain: .inet,
    type: [.stream, .cloexec],
    protocol: .tcp
)
// Connect before sandboxing
try remoteSocket.connect(address: IPv4SocketAddress(
    address: "192.168.1.100",
    port: 8080
))

// 3. Create socket pairs for IPC (if forking)
let pair = try SocketCapability.socketPair(
    domain: .unix,
    type: [.seqpacket, .cloexec]
)

// Now enter capability mode
try Capsicum.enterCapabilityMode()

// After this point:
// - listener can still accept() new connections
// - remoteSocket can read/write on its existing connection
// - pair can be used for IPC
// - Cannot create new sockets or connect to new addresses
