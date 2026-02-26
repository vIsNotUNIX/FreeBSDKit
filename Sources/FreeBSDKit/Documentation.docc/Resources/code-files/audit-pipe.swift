import Audit

// Open the audit pipe (requires root)
let pipe = try Audit.Pipe()

// Configure the pipe
try pipe.set(queueLimit: 1000)

// Set preselection mode to local (use our own mask)
try pipe.set(preselectionMode: .local)

// Set preselection mask to capture file events
try pipe.set(preselectionMask: Audit.Mask(
    success: [.fileRead, .fileWrite, .fileCreate, .fileDelete],
    failure: [.fileRead, .fileWrite, .fileCreate, .fileDelete]
))

print("Audit pipe configured")
print("Queue limit: \(try pipe.queueLimit())")
print("Max audit data size: \(try pipe.maxAuditDataSize())")
