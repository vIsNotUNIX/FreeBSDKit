import Capabilities
import Descriptors
import Foundation
import Glibc

// Create a connected socket pair
let pair = try SocketCapability.socketPair(
    domain: .unix,
    type: [.seqpacket, .cloexec]
)

// Fork a child process
let pid = fork()

if pid == 0 {
    // Child process - use pair.second
    // pair.first is automatically closed (CLOEXEC)

    let socket = pair.second

    // Receive message from parent
    let data = try! socket.read(count: 1024)
    print("Child received: \(String(data: data, encoding: .utf8) ?? "")")

    // Send reply
    try! socket.write(Data("Hello from child!".utf8))
    _exit(0)
} else {
    // Parent process - use pair.first
    // pair.second is closed in parent

    let socket = pair.first

    // Send message to child
    try socket.write(Data("Hello from parent!".utf8))

    // Receive reply
    let reply = try socket.read(count: 1024)
    print("Parent received: \(String(data: reply, encoding: .utf8) ?? "")")

    // Wait for child
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}
