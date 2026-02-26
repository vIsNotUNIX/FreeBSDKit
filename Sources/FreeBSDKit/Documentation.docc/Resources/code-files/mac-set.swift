import MacLabel

// Create a label
var label = MACLabel()
label.add(policy: "bsdextended", label: "ugid=0:0")

// Set the label on a file (requires appropriate privileges)
try MACLabel.set(path: "/tmp/protected", label: label)

print("MAC label set")
