import Jails
import Rctl

// Create a jail first
var params = JailParameters()
params.name = "limited"
params.path = "/jails/limited"
let jid = try Jail.create(parameters: params)

// Now apply resource limits using rctl
// Note: rctl must be enabled in the kernel

// Limit memory to 1GB
try Rctl.add(rule: "jail:limited:memoryuse:deny=1G")

// Limit CPU usage to 50%
try Rctl.add(rule: "jail:limited:pcpu:deny=50")

// Limit to 100 processes
try Rctl.add(rule: "jail:limited:maxproc:deny=100")

// Limit open files
try Rctl.add(rule: "jail:limited:openfiles:deny=1000")

// Log when thresholds are exceeded
try Rctl.add(rule: "jail:limited:memoryuse:log=512M")

print("Resource limits applied to jail 'limited'")

// View current rules
let rules = try Rctl.getRules(filter: "jail:limited")
for rule in rules {
    print("Rule: \(rule)")
}
