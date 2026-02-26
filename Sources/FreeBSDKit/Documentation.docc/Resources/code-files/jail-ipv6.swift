import Jails

var params = JailParameters()
params.name = "webserver6"
params.path = "/jails/webserver6"
params.hostname = "webserver6.local"

// Assign IPv6 addresses
params.ip6 = [
    IPv6Address("2001:db8::1")!,
    IPv6Address("fd00::100")!
]

// IPv6 mode
params.ip6Mode = .new

// Can have both IPv4 and IPv6
params.ip4 = [IPv4Address("192.168.1.100")!]
params.ip4Mode = .new

let jid = try Jail.create(parameters: params)
print("Dual-stack jail created")
