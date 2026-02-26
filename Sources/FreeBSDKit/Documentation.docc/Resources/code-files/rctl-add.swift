import Rctl

// Limit memory for a user
try Rctl.add(rule: "user:www:memoryuse:deny=1G")

// Limit CPU for a jail
try Rctl.add(rule: "jail:webserver:pcpu:deny=50")

// Limit processes for current user
try Rctl.add(rule: "process:\(getpid()):maxproc:deny=50")

// Log when thresholds are exceeded
try Rctl.add(rule: "user:www:memoryuse:log=512M")

print("Resource limits applied")
