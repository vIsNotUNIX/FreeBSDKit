import Jails

var params = JailParameters()
params.name = "secure"
params.path = "/jails/secure"

// Securelevel controls what operations are allowed
// -1: No securelevel restrictions (default)
//  0: Insecure mode (normal operation)
//  1: Secure mode (no loading kernel modules, etc.)
//  2: Highly secure (no direct disk access, etc.)
//  3: Network secure (no IP configuration changes)

params.securelevel = 2

// The jail's securelevel cannot be lowered below host's securelevel
// Child jails cannot have lower securelevel than parent

let jid = try Jail.create(parameters: params)
print("Created secure jail with securelevel 2")
