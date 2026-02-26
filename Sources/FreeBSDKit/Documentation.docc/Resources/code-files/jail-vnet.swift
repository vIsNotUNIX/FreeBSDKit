import Jails

// VNET gives the jail its own complete network stack
// including routing tables, firewall rules, etc.

var params = JailParameters()
params.name = "vnetjail"
params.path = "/jails/vnetjail"
params.hostname = "vnetjail.local"

// Enable VNET - virtualized network stack
params.vnet = true

// With VNET, you assign network interfaces instead of IPs
// This is typically done after jail creation using ifconfig

let jid = try Jail.create(parameters: params)
print("VNET jail created with JID: \(jid)")

// After creation, assign an interface:
// # ifconfig epair0 create
// # ifconfig epair0b vnet vnetjail
// # jexec vnetjail ifconfig epair0b 192.168.1.100/24
