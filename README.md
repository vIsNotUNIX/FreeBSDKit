# FreeBSDKit

A framework for building secure, capability-aware applications on FreeBSD.

FreeBSDKit provides idiomatic Swift, C and C++ interfaces to FreeBSD's unique system features including Capsicum sandboxing, jails, process descriptors, kqueue-based signal handling, and inter-process communication with descriptor passing. The framework embraces move-only semantics (`~Copyable`) to model resource ownership explicitly in the type system.

## Requirements

- FreeBSD 13.0 or later
- Swift 6.2 or later

## Installation

Add FreeBSDKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your/FreeBSDKit", from: "1.0.0")
]
```

Then add the specific libraries you need to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Capsicum", package: "FreeBSDKit"),
        .product(name: "Casper", package: "FreeBSDKit"),
        .product(name: "Descriptors", package: "FreeBSDKit"),
        .product(name: "FPC", package: "FreeBSDKit"),
    ]
)
```

---

## Libraries

### FreeBSDKit (Core)

Foundation protocols and utilities shared across the framework.

```swift
import FreeBSDKit

// Type-safe sysctl access
let hostname: String = try BSDSysctl.getString("kern.hostname")
let boottime: timeval = try BSDSysctl.get("kern.boottime")
let physmem: Int64 = try BSDSysctl.get("hw.physmem")

// Extended attributes
try ExtendedAttributes.set(
    path: "/path/to/file",
    namespace: .user,
    name: "myattr",
    data: "value".data(using: .utf8)!
)

let data = try ExtendedAttributes.get(
    path: "/path/to/file",
    namespace: .user,
    name: "myattr"
)
```

**Key Types:**
- `BSDSysctl` - Type-safe sysctl reading and writing
- `ExtendedAttributes` - Extended attribute operations on files and descriptors
- `BSDError` - Unified error handling for BSD system calls
- `BSDSignal` - Signal enumeration with catchability checks
- `BSDResource` - Protocol for ownership-aware resources

---

### Capsicum

Swift interface to FreeBSD's Capsicum capability-mode sandbox.

```swift
import Capsicum

// Check if already in capability mode
let inCapMode = try Capsicum.status()

// Enter capability mode (irreversible)
try Capsicum.enter()

// After this point, global namespaces are inaccessible.
// Only operations on existing file descriptors with
// appropriate rights are permitted.
```

**Limiting Descriptor Rights:**

```swift
import Capsicum

// Create a right set with specific capabilities
let rights = CapsicumRightSet(rights: [
    .read,
    .write,
    .fstat,
    .seek
])

// Limit a file descriptor (rights can only be reduced, never expanded)
_ = CapsicumHelper.limit(fd: fd, rights: rights)

// Limit allowed fcntl operations
try CapsicumHelper.limitFcntls(fd: fd, rights: [.getfl, .setfl])

// Limit allowed ioctl commands
try CapsicumHelper.limitIoctls(fd: fd, commands: [
    IoctlCommand(rawValue: FIONREAD)
])
```

**Key Types:**
- `Capsicum` - Enter capability mode and query status
- `CapsicumRightSet` - Set of capability rights for a descriptor
- `CapsicumRight` - Individual capability rights (read, write, seek, etc.)
- `FcntlRights` - Allowed fcntl operations
- `IoctlCommand` - Allowed ioctl commands

---

### Descriptors

Move-only descriptor types with explicit ownership semantics.

```swift
import Descriptors

// All descriptors are ~Copyable (move-only)
// Ownership transfers on assignment, preventing use-after-close

var file = FileCapability(fd)

// Read from a descriptor
let result = try file.read(maxBytes: 4096)
switch result {
case .data(let bytes):
    print("Read \(bytes.count) bytes")
case .eof:
    print("End of file")
}

// Write to a descriptor
let written = try file.writeOnce(data)

// Descriptor is closed when consumed
file.close()
```

**Socket Operations:**

```swift
import Descriptors

// Create a Unix domain socket
var socket = try SocketCapability.create(
    domain: .unix,
    type: .stream,
    protocol: 0
)

// Bind and listen
try socket.bind(path: "/tmp/my.sock")
try socket.listen(backlog: 5)

// Accept connections
var client = try socket.accept()
```

**Pipe Operations:**

```swift
import Descriptors

// Create a pipe pair
let (read, write) = try PipeCapability.create()

// Write to the pipe
try write.writeOnce("Hello".data(using: .utf8)!)

// Read from the pipe
let result = try read.read(maxBytes: 100)
```

**Device Operations:**

```swift
import Descriptors

// Open a device
var device = try DeviceCapability.open(
    path: "/dev/random",
    flags: [.readOnly]
)

// Read random bytes
let result = try device.read(maxBytes: 32)

// Query device properties
let deviceType = try device.deviceType()
let isDisk = try device.isDisk()

// For block devices
let sectorSize = try device.sectorSize()
let mediaSize = try device.mediaSize()
```

**Key Types:**
- `FileCapability` - Regular file descriptor
- `DirectoryCapability` - Directory descriptor with openat support
- `DeviceCapability` - Device file descriptor with ioctl support
- `SocketCapability` - Socket descriptor
- `PipeReadCapability` / `PipeWriteCapability` - Pipe endpoints
- `KqueueCapability` - Kqueue event notification
- `ProcessCapability` - Process descriptor (pdfork)
- `SharedMemoryCapability` - POSIX shared memory
- `EventCapability` - Eventfd-like notifications
- `SystemJailDescriptor` - Jail descriptor

---

### Capabilities

Capsicum capability wrappers for descriptors with built-in right limiting.

```swift
import Capabilities

// Open a file with capability wrapping
var file = FileCapability(fd)

// Limit rights directly on the capability
_ = file.limit(rights: CapsicumRightSet(rights: [.read, .fstat]))

// Limit fcntl/ioctl operations
try file.limitFcntls(rights: [.getfl])
try file.limitIoctls(commands: [])

// Query current limits
let fcntls = try file.getFcntls()
let ioctls = try file.getIoctls()
```

**Directory-Relative Operations (Capsicum-Safe):**

```swift
import Capabilities

// Open a directory capability
var dir = try DirectoryCapability.open(path: "/var/data")

// Open files relative to the directory (works in capability mode)
var file = try dir.openFile(relativePath: "config.json", flags: [.readOnly])

// Create subdirectories
try dir.createDirectory(relativePath: "cache", mode: 0o755)

// Stat files relative to directory
let st = try dir.stat(relativePath: "config.json")
```

---

### SignalDispatchers

Kqueue and libdispatch-based signal handling.

```swift
import SignalDispatchers
import Descriptors

// Create a kqueue for signal delivery
var kq = try KqueueCapability.create()

// Create dispatcher for specific signals
let dispatcher = try KqueueSignalDispatcher(
    kqueue: kq,
    signals: [.int, .term, .hup]
)

// Register handlers
await dispatcher.on(.int) {
    print("Received SIGINT")
}

await dispatcher.on(.term) {
    print("Received SIGTERM, shutting down...")
}

// Run the dispatch loop (never returns normally)
try await dispatcher.run()
```

**Using libdispatch:**

```swift
import SignalDispatchers

// Dispatch-based signal handling
let dispatcher = try DispatchSignalDispatcher(signals: [.int, .term])

dispatcher.on(.int) {
    print("SIGINT received")
}

dispatcher.on(.term) {
    print("SIGTERM received")
}

// Signals are delivered via GCD
```

---

### Jails

Interface to FreeBSD jail management.

```swift
import Jails
import Descriptors

// Build jail parameters
var iov = JailIOVector()
iov.add(key: "name", value: "myjail")
iov.add(key: "path", value: "/jail/myjail")
iov.add(key: "host.hostname", value: "jailed.local")
iov.add(key: "persist", value: true)

// Create jail and get descriptor
let flags: JailSetFlags = [.create, .getDesc, .ownDesc]
var jailDesc = try SystemJailDescriptor.set(iov: &iov, flags: flags)

// Attach current process to jail
try jailDesc.attach()

// Remove jail (requires owning descriptor)
try jailDesc.remove()
```

---

### FPC (Free Process Communication)

IPC protocol with descriptor passing over Unix sockets.

```swift
import FPC

// Server side
let listener = try FPCListener(path: "/tmp/myservice.sock")

while true {
    var endpoint = try await listener.accept()

    // Receive a message
    var request = try await endpoint.receive()

    // Extract descriptors from message
    if let file = request.fileDescriptor(at: 0) {
        // Process the received file descriptor
    }

    // Send a reply
    let reply = FPCMessage.reply(to: request, id: .pong)
    try await endpoint.send(reply)
}
```

**Client Side:**

```swift
import FPC

// Connect to server
var endpoint = try await FPCClient.connect(path: "/tmp/myservice.sock")

// Send a request with file descriptors
var fd = FileCapability(openedFd)
let message = FPCMessage.request(
    .lookup,
    payload: "config".data(using: .utf8)!,
    descriptors: [fd.toOpaqueRef()]
)
try await endpoint.send(message)

// Receive reply
let reply = try await endpoint.receive()
```

**Custom Message IDs:**

```swift
extension MessageID {
    // User message IDs start at 256
    static let fileOpen = MessageID(rawValue: 256)
    static let fileOpenReply = MessageID(rawValue: 257)
    static let processSpawn = MessageID(rawValue: 258)
}
```

**Wire Format:**
- 16-byte header with version, message ID, correlation ID, flags
- Up to 64KB inline payload
- Up to 16 file descriptors per message
- Out-of-line (OOL) support for larger payloads via shared memory

---

### MacLabel

Security labeling tool for FreeBSD MAC Framework integration.

```swift
import MacLabel

// Load configuration from JSON
let config = try LabelConfiguration<FileLabel>.load(from: configPath)

// Create labeler
var labeler = Labeler(configuration: config)
labeler.verbose = true

// Validate all paths exist before applying
try labeler.validateConfiguration()

// Apply labels to files
let results = try labeler.apply()

for result in results {
    if result.success {
        print("Labeled: \(result.path)")
    } else {
        print("Failed: \(result.path) - \(result.error!)")
    }
}

// Verify labels match configuration
let verification = try labeler.verify()
```

**Configuration Format (JSON):**

```json
{
    "attributeName": "mac_labels",
    "labels": [
        {
            "path": "/usr/local/bin/myapp",
            "attributes": {
                "security_level": "high",
                "network_access": "restricted"
            }
        },
        {
            "path": "/var/data/*",
            "attributes": {
                "data_class": "sensitive"
            }
        }
    ]
}
```

**CLI Tool (`maclabel`):**

```bash
# Validate configuration
maclabel validate -c config.json

# Apply labels
sudo maclabel apply -c config.json

# Show current labels
maclabel show -c config.json

# Verify labels match configuration
maclabel verify -c config.json

# Remove labels
sudo maclabel remove -c config.json
```

---

### Casper

Swift interface to FreeBSD's Casper (libcasper) services for use in Capsicum sandboxes.

Casper provides privileged services to capability-mode processes that lack direct access to global namespaces. Each service runs in a separate sandboxed process and communicates via Unix domain sockets.

```swift
import Casper
import Capsicum

// Initialize Casper BEFORE entering capability mode (single-threaded context)
let casper = try CasperChannel.create()

// Open services you need
let dns = try CasperDNS(casper: casper)
let sysctl = try CasperSysctl(casper: casper)
let pwd = try CasperPwd(casper: casper)
let grp = try CasperGrp(casper: casper)

// Limit services to minimum required operations
try dns.limitTypes([.nameToAddress])
try dns.limitFamilies([AF_INET, AF_INET6])
try sysctl.limitNames([
    ("kern.hostname", .read),
    ("hw.physmem", .read)
])
try pwd.limitUsers(names: ["root", "www"])
try pwd.limitCommands([.getpwnam, .getpwuid])

// Enter capability mode
try Capsicum.enter()

// Use services within the sandbox
let addresses = try dns.getaddrinfo(hostname: "example.com", port: "443")
let hostname = try sysctl.getString("kern.hostname")
if let user = pwd.getpwnam("www") {
    print("www uid: \(user.uid)")
}
```

**Available Services:**

| Service | Purpose | Key Operations |
|---------|---------|----------------|
| `CasperDNS` | DNS resolution | `getaddrinfo`, `getnameinfo`, `gethostbyname` |
| `CasperSysctl` | Sysctl access | `get`, `set`, `getString`, `nameToMIB` |
| `CasperPwd` | Password database | `getpwnam`, `getpwuid`, `getpwent` |
| `CasperGrp` | Group database | `getgrnam`, `getgrgid`, `getgrent` |
| `CasperSyslog` | System logging | `openlog`, `syslog`, `closelog` |

**Syslog Service:**

```swift
import Casper

let casper = try CasperChannel.create()
let syslog = try CasperSyslog(casper: casper)

// Open connection to syslog
syslog.openlog(ident: "myapp", options: [.pid, .cons], facility: .daemon)

// Log messages within capability mode
syslog.syslog(priority: .info, message: "Application started")
syslog.syslog(priority: .err, message: "Something went wrong")

// Close when done
syslog.closelog()
```

---

### CMacLabelParser

Dependency-free C library for parsing MAC labels.

```c
#include <maclabel_parser.h>

// Parse label data
maclabel_parser_t parser;
maclabel_parser_init(&parser, label_data, label_len);

// Iterate over key-value pairs
const char *key, *value;
size_t key_len, value_len;

while (maclabel_parser_next(&parser, &key, &key_len, &value, &value_len) == 0) {
    printf("%.*s = %.*s\n", (int)key_len, key, (int)value_len, value);
}
```

This library is designed for use in kernel modules, boot loaders, or other environments where Swift or the full FreeBSDKit framework is not available.

---

## Design Principles

### Move-Only Types (`~Copyable`)

All descriptor types are move-only to prevent common resource management bugs:

```swift
var file = FileCapability(fd)
let copy = file  // Ownership transfers, 'file' is now invalid
// file.read()   // Compile error: 'file' used after being consumed
```

### Explicit Ownership

Resources can be consumed to extract the underlying handle:

```swift
var socket = SocketCapability(fd)
let rawFd: Int32 = socket.take()  // Socket is consumed, caller owns fd
// Caller is now responsible for closing rawFd
```

### Capability-Based Security

The framework is designed around Capsicum's capability model:

```swift
// Open resources before entering capability mode
var configDir = try DirectoryCapability.open(path: "/etc/myapp")
var dataDir = try DirectoryCapability.open(path: "/var/myapp")
var logFile = try FileCapability.open(path: "/var/log/myapp.log", flags: [.writeOnly, .append])

// Limit rights to minimum needed
_ = configDir.limit(rights: CapsicumRightSet(rights: [.read, .lookup]))
_ = dataDir.limit(rights: CapsicumRightSet(rights: [.read, .write, .lookup, .create]))
_ = logFile.limit(rights: CapsicumRightSet(rights: [.write]))

// Enter sandbox
try Capsicum.enter()

// Now only operations on these descriptors with their limited rights are allowed
```

---

## C Bridge Modules

Several C modules provide access to macros and inline functions that Swift cannot import directly:

| Module | Purpose |
|--------|---------|
| `CCapsicum` | Capsicum rights macros and helper functions |
| `CCasper` | Casper (libcasper) service wrappers |
| `CJails` | Jail flag constants and wrapper functions |
| `CProcessDescriptor` | Process descriptor (pdfork) functions |
| `CEventDescriptor` | Event notification functions |
| `CDeviceIoctl` | Device ioctl constants (FIONREAD, DIOCGSECTORSIZE, etc.) |
| `CSignal` | Signal handling macros |
| `CExtendedAttributes` | Extended attribute constants |

---

## Testing

```bash
swift test
```

Tests require root privileges for some Capsicum and jail functionality. Tests that require elevated privileges are skipped when running as a regular user.

---

## License

BSD-2-Clause

---

## Non-Goals

FreeBSDKit intentionally does **not**:

- Provide cross-platform compatibility
- Abstract away FreeBSD-specific semantics
- Support non-FreeBSD operating systems

This project embraces FreeBSD's identity and unique features rather than hiding them behind portable abstractions.
