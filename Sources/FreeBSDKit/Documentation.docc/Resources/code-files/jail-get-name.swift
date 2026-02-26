import Jails

// Get jail information by name
let name = "webserver"

do {
    let info = try Jail.get(name: name)

    print("Found jail '\(name)':")
    print("  JID: \(info.jid)")
    print("  Path: \(info.path)")
    print("  Hostname: \(info.hostname)")
    print("  VNET: \(info.vnet)")
    print("  Persist: \(info.persist)")
} catch JailError.notFound {
    print("Jail '\(name)' not found")
} catch {
    print("Error: \(error)")
}
