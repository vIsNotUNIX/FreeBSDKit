import Jails

var params = JailParameters()
params.name = "webserver"
params.path = "/jails/webserver"
params.hostname = "webserver.local"

// Assign IPv4 addresses
// Multiple addresses can be assigned
params.ip4 = [
    IPv4Address("192.168.1.100")!,
    IPv4Address("192.168.1.101")!
]

// Address inheritance mode:
// .new - Jail gets its own address (default)
// .inherit - Jail shares host's addresses
// .disable - No IPv4 networking
params.ip4Mode = .new

// Create the jail
let jid = try Jail.create(parameters: params)
print("Jail created with IPv4: 192.168.1.100, 192.168.1.101")
