# FPC - BSD Protocol Communication

A Swift actor-based IPC library for FreeBSD using Unix-domain SEQPACKET sockets.

## Features

- **Actor-isolated endpoints** - Thread-safe by design
- **Request/reply correlation** - Automatic matching of replies to requests
- **File descriptor passing** - Send sockets, files, pipes, shared memory, etc.
- **Out-of-line payloads** - Large messages automatically use shared memory
- **Timeout support** - Optional per-request timeouts
- **Capsicum compatible** - Works in capability mode

## Quick Start

### Client

```swift
import FPC

// Connect to a server
let endpoint = try BSDClient.connect(path: "/tmp/my-service.sock")
await endpoint.start()

// Send a request and wait for reply
let request = Message.request(.lookup, payload: Data("query".utf8))
let reply = try await endpoint.request(request, timeout: .seconds(5))

// Process reply
print("Got reply: \(reply.id)")

await endpoint.stop()
```

### Server

```swift
import FPC

// Create listener
let listener = try BSDListener.listen(on: "/tmp/my-service.sock")
listener.start()

// Accept connections
for try await client in try listener.connections() {
    await client.start()

    Task {
        for await message in try client.messages() {
            // Handle request
            if message.id == .lookup {
                try await client.reply(to: message, id: .lookupReply, payload: result)
            }
        }
    }
}
```

### Paired Endpoints (Testing)

```swift
// Create connected pair without sockets
let (client, server) = try BSDEndpoint.pair()
await client.start()
await server.start()
```

## Messages

Messages carry a typed ID, optional payload, and optional file descriptors:

```swift
// Create a request (correlation ID assigned automatically)
let msg = Message.request(.ping, payload: Data([1, 2, 3]))

// Create a reply (copies correlation ID from request)
let reply = Message.reply(to: request, id: .pong, payload: responseData)

// Access message fields
msg.id              // MessageID
msg.correlationID   // UInt64 (0 = unsolicited, non-zero = request/reply)
msg.payload         // Data
msg.descriptors     // [OpaqueDescriptorRef]
```

### Message IDs

System-reserved IDs (0-255):

| ID | Name | Description |
|----|------|-------------|
| 1 | `.ping` | Liveness probe |
| 2 | `.pong` | Ping response |
| 3 | `.lookup` | Name lookup request |
| 4 | `.lookupReply` | Lookup response |
| 5 | `.subscribe` | Event subscription |
| 6 | `.subscribeAck` | Subscription acknowledgement |
| 7 | `.event` | Unsolicited event |
| 255 | `.error` | Error response |

User-defined IDs start at 256:

```swift
extension MessageID {
    static let fileOpen = MessageID(rawValue: 256)
    static let fileOpenReply = MessageID(rawValue: 257)
}
```

## File Descriptor Passing

Send file descriptors alongside messages:

```swift
// Sending
let file = try FileCapability.open(path: "/etc/passwd", flags: .readOnly)
let ref = OpaqueDescriptorRef(file.take()!, kind: .file)
let msg = Message(id: .fileOpen, descriptors: [ref])
try await endpoint.send(msg)

// Receiving
if let fd = message.descriptor(at: 0, expecting: .file) {
    let file = FileCapability(fd)
    // Use file...
}

// Or extract with ownership transfer
if var file = message.fileDescriptor(at: 0) {
    // file is now owned by caller
}
```

Supported descriptor kinds:
- `.file` - Regular files
- `.socket` - Sockets
- `.pipe` - Pipes
- `.process` - Process descriptors (pdfork)
- `.kqueue` - Kqueue descriptors
- `.shm` - Shared memory
- `.event` - Event descriptors
- `.jail(owning:)` - Jail descriptors

## Wire Format

FPC uses a fixed-size header/trailer format with variable payload:

```
[Header: 256 bytes][Payload: variable][Trailer: 256 bytes]
```

### Header Layout

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 | messageID (UInt32, host-endian) |
| 4 | 8 | correlationID (UInt64, host-endian) |
| 12 | 4 | payloadLength (UInt32, host-endian) |
| 16 | 1 | descriptorCount (max 254) |
| 17 | 1 | version (currently 0) |
| 18 | 1 | flags (bit 0 = OOL payload) |
| 19-255 | 237 | reserved |

### Trailer Layout

| Offset | Size | Field |
|--------|------|-------|
| 0-253 | 254 | descriptorKinds (1 byte each) |
| 254-255 | 2 | reserved |

### Out-of-Line Payloads

When payload exceeds the kernel's SEQPACKET limit (~64KB on FreeBSD), FPC automatically:

1. Creates anonymous shared memory
2. Writes payload to shared memory
3. Sends shm descriptor instead of inline payload
4. Sets OOL flag in header

This is transparent to the application.

## Correlation IDs

- `0` = Unsolicited message (events, notifications)
- Non-zero = Request/reply correlation

The 64-bit correlation ID space effectively never wraps (~585 years at 1 billion msg/sec).

## Error Handling

```swift
do {
    let reply = try await endpoint.request(msg, timeout: .seconds(5))
} catch FPCError.timeout {
    // Request timed out
} catch FPCError.disconnected {
    // Connection lost
} catch FPCError.stopped {
    // Endpoint was stopped
}
```

All FPCError cases:
- `.disconnected` - Connection lost
- `.stopped` - Endpoint explicitly stopped
- `.listenerClosed` - Listener socket closed
- `.notStarted` - start() not called
- `.streamAlreadyClaimed` - messages() already claimed
- `.invalidMessageFormat` - Malformed wire data
- `.unsupportedVersion(UInt8)` - Unknown protocol version
- `.unexpectedMessage(MessageID)` - Message not valid in context
- `.timeout` - Request timed out
- `.tooManyDescriptors(Int)` - Exceeded 254 descriptor limit

## Testing

FPC includes comprehensive tests for the wire format:

```bash
swift test --filter FPCTests
```

For socket communication tests, use `BSDEndpoint.pair()` with detached tasks to avoid actor deadlocks.

## Architecture

```
FPCEndpoint (protocol)
    └── BSDEndpoint (actor)
            ├── SocketHolder (thread-safe socket wrapper)
            ├── WireFormat (encoding/decoding)
            └── DispatchQueue (I/O operations)

FPCListener (protocol)
    └── BSDListener (actor)
            └── SocketHolder

FPCClient (protocol)
    └── BSDClient (struct)
```

## Thread Safety

- All endpoint methods are actor-isolated
- Socket I/O runs on a dedicated DispatchQueue
- SocketHolder uses NSLock for cross-isolation access
- Correlation ID tracking is actor-protected

## Limitations

- **Local only** - Unix-domain sockets, same-host communication
- **Host-endian** - Wire format uses native byte order (not portable)
- **Max 254 descriptors** - Per-message limit
- **Single stream consumer** - Only one task can consume `messages()`
