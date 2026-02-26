import Jails

// Remove a jail by JID
func removeJail(jid: Int32) throws {
    // First, kill all processes in the jail
    try Jail.killAllProcesses(jid: jid)

    // Then remove the jail
    try Jail.remove(jid: jid)

    print("Jail \(jid) removed")
}

// Remove by name
func removeJail(name: String) throws {
    // Get JID from name
    let info = try Jail.get(name: name)

    // Kill processes and remove
    try Jail.killAllProcesses(jid: info.jid)
    try Jail.remove(jid: info.jid)

    print("Jail '\(name)' (JID \(info.jid)) removed")
}

// Usage
// try removeJail(jid: 1)
// try removeJail(name: "webserver")
