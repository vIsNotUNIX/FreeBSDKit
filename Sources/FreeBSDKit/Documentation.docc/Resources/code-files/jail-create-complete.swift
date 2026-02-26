import Jails
import Foundation

/// Create a basic FreeBSD jail
func createJail(name: String, rootPath: String) throws -> Int32 {
    // Verify the root path exists
    guard FileManager.default.fileExists(atPath: rootPath) else {
        throw JailError.invalidPath
    }

    // Build jail parameters
    var params = JailParameters()
    params.name = name
    params.path = rootPath
    params.hostname = "\(name).local"

    // Keep jail alive even with no processes
    params.persist = true

    // Create the jail
    let jid = try Jail.create(parameters: params)

    print("Jail '\(name)' created successfully")
    print("  JID: \(jid)")
    print("  Path: \(rootPath)")
    print("  Hostname: \(name).local")

    return jid
}

// Usage (requires root):
// let jid = try createJail(name: "webserver", rootPath: "/jails/webserver")
