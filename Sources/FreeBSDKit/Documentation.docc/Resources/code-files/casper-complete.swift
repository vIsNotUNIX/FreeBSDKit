import Casper
import Capsicum
import Capabilities
import Descriptors
import Foundation

/// A sandboxed network client that uses Casper services
struct SandboxedNetworkClient {
    let socket: SocketCapability
    let dns: Casper.DNSService
    let syslog: Casper.SyslogService

    /// Create and sandbox the client
    static func create(host: String, port: UInt16) throws -> SandboxedNetworkClient {
        // Initialize Casper services BEFORE sandboxing
        let casper = try Casper()
        let dns = try casper.service(.dns)
        let syslog = try casper.service(.syslog)

        // Limit DNS to IPv4/IPv6
        try dns.limit(families: [.inet, .inet6], types: ["A", "AAAA"])

        // Create socket
        let socket = try SocketCapability.socket(
            domain: .inet,
            type: [.stream, .cloexec],
            protocol: .tcp
        )

        // Resolve hostname and connect BEFORE sandboxing
        let addresses = try dns.resolve(hostname: host)
        guard let addr = addresses.first else {
            throw BSDError.noSuchFileOrDirectory
        }

        try socket.connect(address: IPv4SocketAddress(
            address: addr.ipv4String!,
            port: port
        ))

        // Log connection
        try syslog.log(priority: .info, message: "Connected to \(host):\(port)")

        // Enter capability mode
        try Capsicum.enterCapabilityMode()

        return SandboxedNetworkClient(
            socket: socket,
            dns: dns,
            syslog: syslog
        )
    }

    /// Send a request and receive response
    func request(_ message: String) throws -> String {
        try syslog.log(priority: .debug, message: "Sending request")

        // Send request
        try socket.write(Data(message.utf8))

        // Receive response
        let response = try socket.read(count: 65536)

        try syslog.log(priority: .debug, message: "Received \(response.count) bytes")

        return String(data: response, encoding: .utf8) ?? ""
    }
}

// Usage
let client = try SandboxedNetworkClient.create(
    host: "api.example.com",
    port: 443
)

// Now fully sandboxed, but can still:
// - Send/receive on the connected socket
// - Log via syslog
// - Resolve hostnames via DNS (for display, not new connections)

let response = try client.request("GET / HTTP/1.1\r\nHost: api.example.com\r\n\r\n")
print(response)
