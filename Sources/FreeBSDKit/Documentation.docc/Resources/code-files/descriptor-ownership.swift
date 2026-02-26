import Capabilities
import Descriptors

func example() throws {
    // FileCapability is a move-only type (~Copyable)
    let file = try FileCapability.open(
        path: "/tmp/example.txt",
        flags: .readOnly
    )

    // Use the file...
    let data = try file.read(count: 1024)
    print("Read \(data.count) bytes")

    // When 'file' goes out of scope, the descriptor is automatically closed
    // No need to call close() - it happens automatically!
}

// This prevents resource leaks and double-close bugs
