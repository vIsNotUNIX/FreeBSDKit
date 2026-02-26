import Rctl

// Get all rules for a subject
let rules = try Rctl.getRules(filter: "user:www")

print("Rules for user 'www':")
for rule in rules {
    print("  \(rule)")
}

// Get resource usage
let usage = try Rctl.getUsage(filter: "user:www")
print("\nResource usage:")
print("  Memory: \(usage.memoryuse) bytes")
print("  CPU: \(usage.pcpu)%")
print("  Processes: \(usage.maxproc)")
