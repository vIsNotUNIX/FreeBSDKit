import Jails

// Get existing jail
let jid = try Jail.get(name: "myjail").jid

// Update parameters on running jail
var updates = JailParameters()

// Change hostname
updates.hostname = "new-hostname.local"

// Add new IP addresses
updates.ip4 = [IPv4Address("192.168.1.200")!]

// Enable raw sockets
updates.allowRawSockets = true

// Apply updates
try Jail.update(jid: jid, parameters: updates)

print("Jail \(jid) updated")

// Verify changes
let info = try Jail.get(jid: jid)
print("New hostname: \(info.hostname)")
print("New IP: \(info.ip4?.first?.description ?? "none")")
