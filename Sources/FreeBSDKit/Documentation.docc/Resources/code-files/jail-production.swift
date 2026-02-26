import Jails
import Rctl
import Foundation

/// Create a production-ready web server jail
struct ProductionJail {
    let name: String
    let rootPath: String
    let ipAddress: String
    let memoryLimit: String
    let cpuLimit: Int

    func create() throws -> Int32 {
        // Verify root filesystem exists
        guard FileManager.default.fileExists(atPath: rootPath) else {
            throw JailError.invalidPath
        }

        // Build jail parameters
        var params = JailParameters()

        // Identity
        params.name = name
        params.path = rootPath
        params.hostname = "\(name).example.com"

        // Networking
        params.ip4 = [IPv4Address(ipAddress)!]
        params.ip4Mode = .new

        // Security - restrictive by default
        params.securelevel = 1
        params.allowRawSockets = false
        params.allowSetHostname = false
        params.allowSysvipc = false
        params.allowChflags = false
        params.allowJails = false

        // Filesystem
        params.allowMount = false
        params.allowMountDevfs = true   // Need /dev
        params.devfsRuleset = 4
        params.enforceStatfs = 2

        // Persistence
        params.persist = true

        // Create jail
        let jid = try Jail.create(parameters: params)

        // Apply resource limits
        try Rctl.add(rule: "jail:\(name):memoryuse:deny=\(memoryLimit)")
        try Rctl.add(rule: "jail:\(name):pcpu:deny=\(cpuLimit)")
        try Rctl.add(rule: "jail:\(name):maxproc:deny=200")
        try Rctl.add(rule: "jail:\(name):openfiles:deny=5000")

        print("Production jail '\(name)' created:")
        print("  JID: \(jid)")
        print("  IP: \(ipAddress)")
        print("  Memory limit: \(memoryLimit)")
        print("  CPU limit: \(cpuLimit)%")

        return jid
    }
}

// Usage
let webserver = ProductionJail(
    name: "webserver",
    rootPath: "/jails/webserver",
    ipAddress: "192.168.1.100",
    memoryLimit: "2G",
    cpuLimit: 80
)

// let jid = try webserver.create()
