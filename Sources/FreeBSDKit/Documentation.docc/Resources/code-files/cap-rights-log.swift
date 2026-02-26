import Capsicum
import Capabilities
import Descriptors

// Log file: append-only, cannot read or truncate
let logFile = try FileCapability.open(
    path: "/var/log/myapp.log",
    flags: [.writeOnly, .append, .create],
    mode: 0o644
)

// Append-only rights
try logFile.limitRights(to: [
    .write,     // Write data
    .fsync,     // Flush to disk
    .fstat,     // Get file info
    // No .read - can't read log contents
    // No .seek - can't seek (append-only anyway)
    // No .ftruncate - can't clear the log
])

// Write a log entry
let timestamp = ISO8601DateFormatter().string(from: Date())
try logFile.write(Data("[\(timestamp)] Application started\n".utf8))

// Force write to disk
try logFile.fsync()

print("Log file secured with append-only rights")
