import Jails

var params = JailParameters()
params.name = "parent"
params.path = "/jails/parent"

// Allow creating child jails
params.allowJails = true

// Limit number of child jails
params.childrenMax = 5              // Maximum 5 child jails

// These parameters are inherited by children
params.childrenCurrent = 0          // Read-only: current child count

// When creating child jails, they'll be named:
// parent.child1, parent.child2, etc.

let jid = try Jail.create(parameters: params)
print("Created parent jail that can have up to 5 children")
