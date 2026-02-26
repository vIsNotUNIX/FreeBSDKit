import Casper
import Capsicum
import Foundation

// Create DNS service before sandboxing
let casper = try Casper()
let dns = try casper.service(.dns)

// Limit DNS to specific address families and types
try dns.limit(families: [.inet, .inet6], types: ["A", "AAAA"])

// Enter capability mode
try Capsicum.enterCapabilityMode()

// Now resolve hostnames from within the sandbox
let addresses = try dns.resolve(hostname: "www.freebsd.org")

for address in addresses {
    switch address {
    case .ipv4(let addr):
        print("IPv4: \(addr)")
    case .ipv6(let addr):
        print("IPv6: \(addr)")
    }
}

// Reverse lookup
if let hostname = try dns.reverseResolve(address: addresses.first!) {
    print("Reverse: \(hostname)")
}
