import Jails

// Get jail information by JID (jail ID)
let jid: Int32 = 1

do {
    let info = try Jail.get(jid: jid)

    print("Jail Information:")
    print("  JID: \(info.jid)")
    print("  Name: \(info.name)")
    print("  Path: \(info.path)")
    print("  Hostname: \(info.hostname)")

    if let ip4 = info.ip4 {
        print("  IPv4: \(ip4.map { $0.description }.joined(separator: ", "))")
    }

    if let ip6 = info.ip6 {
        print("  IPv6: \(ip6.map { $0.description }.joined(separator: ", "))")
    }

    print("  Securelevel: \(info.securelevel)")
    print("  Children: \(info.childrenCurrent)/\(info.childrenMax)")
} catch {
    print("Jail not found: \(error)")
}
