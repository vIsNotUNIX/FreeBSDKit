import Casper
import Capsicum

// Initialize Casper BEFORE entering capability mode
// This creates a connection to the Casper daemon

let casper = try Casper()

// Create the specific services you need
let dns = try casper.service(.dns)
let sysctl = try casper.service(.sysctl)

// Now enter capability mode
try Capsicum.enterCapabilityMode()

// Services remain available for use
// They communicate with privileged helpers via descriptors
