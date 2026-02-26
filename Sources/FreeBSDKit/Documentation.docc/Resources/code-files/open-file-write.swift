import Capabilities
import Descriptors

// Open a file for writing, creating if necessary
let file = try FileCapability.open(
    path: "/tmp/output.txt",
    flags: [.writeOnly, .create, .truncate],
    mode: 0o644  // rw-r--r--
)

// Write some data
let message = "Hello, FreeBSD!\n"
try file.write(Data(message.utf8))

// File is automatically closed when 'file' goes out of scope
