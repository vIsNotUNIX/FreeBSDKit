import Jails

// List all running jails
let jails = try Jail.list()

print("Running Jails:")
print("JID\tName\t\tPath\t\t\tIP")
print("---\t----\t\t----\t\t\t--")

for jail in jails {
    let ip = jail.ip4?.first?.description ?? "-"
    print("\(jail.jid)\t\(jail.name)\t\t\(jail.path)\t\(ip)")
}

print("\nTotal: \(jails.count) jails")
