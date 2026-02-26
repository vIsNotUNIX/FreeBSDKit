import MacLabel

// Get the MAC label of a file
let label = try MACLabel.get(path: "/etc/passwd")

print("MAC Label: \(label)")

// Access individual policies
for policy in label.policies {
    print("  Policy: \(policy.name)")
    print("  Label: \(policy.label)")
}
