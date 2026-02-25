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
        .product(name: "Procctl", package: "FreeBSDKit"),
        .product(name: "ACL", package: "FreeBSDKit"),
        .product(name: "Rctl", package: "FreeBSDKit"),
        .product(name: "Cpuset", package: "FreeBSDKit"),
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

### Procctl

Swift interface to FreeBSD's `procctl(2)` system call for process control operations.

```swift
import Procctl

// ASLR (Address Space Layout Randomization)
let aslrStatus = try Procctl.ASLR.getStatus()
if aslrStatus.isActive {
    print("ASLR is active")
}
try Procctl.ASLR.forceEnable()  // Takes effect on next exec

// Process tracing control
if try Procctl.Trace.isEnabled() {
    try Procctl.Trace.disable()  // Prevent debugging/tracing
}

// Parent death signal (like Linux PR_SET_PDEATHSIG)
try Procctl.ParentDeathSignal.set(signal: SIGTERM)

// No new privileges (prevent setuid escalation)
try Procctl.NoNewPrivileges.enable()

// Capability trap (SIGTRAP on Capsicum violations for debugging)
try Procctl.CapabilityTrap.enable()
```

**Process Reaper (Container/Supervisor Support):**

```swift
import Procctl

// Become a process reaper - orphaned descendants reparent here instead of init
try Procctl.Reaper.acquire()

// Check reaper status
let status = try Procctl.Reaper.getStatus()
print("Children: \(status.childCount), Descendants: \(status.descendantCount)")

// Get PIDs of all descendants
let pids = try Procctl.Reaper.getPids()
for pid in pids {
    print("PID \(pid.pid), zombie: \(pid.isZombie)")
}

// Kill all descendants
let result = try Procctl.Reaper.killAll(signal: SIGTERM)
print("Killed \(result.killed) processes")

// Release reaper role
try Procctl.Reaper.release()
```

**Security Controls:**

```swift
import Procctl

// W^X (Write XOR Execute) enforcement
let wxStatus = try Procctl.WXMap.getStatus()
if !wxStatus.isEnforced {
    try Procctl.WXMap.enforce()  // Prevent simultaneous W+X mappings
}

// PROT_MAX control (limit mprotect upgrades)
try Procctl.ProtMax.forceEnable()

// Stack gap randomization
try Procctl.StackGap.enable()

// OOM killer protection
try Procctl.OOMProtection.protect(options: .inherit)

// Signal exit logging
try Procctl.LogSigExit.forceEnable()
```

**x86_64-Specific Controls:**

```swift
#if arch(x86_64)
import Procctl

// KPTI (Kernel Page Table Isolation) - Meltdown mitigation
let kptiStatus = try Procctl.KPTI.getStatus()
try Procctl.KPTI.enableOnExec()

// Linear address width (LA48 vs LA57)
let laStatus = try Procctl.LinearAddress.getStatus()
if laStatus.isLA57 {
    try Procctl.LinearAddress.setLA48OnExec()  // Use 48-bit addresses
}
#endif
```

**Available Controls:**

| Control | Purpose |
|---------|---------|
| `ASLR` | Address space layout randomization |
| `Trace` | Process tracing/debugging control |
| `ProtMax` | Implicit PROT_MAX for mprotect |
| `StackGap` | Stack gap randomization |
| `NoNewPrivileges` | Prevent privilege escalation via setuid |
| `CapabilityTrap` | SIGTRAP on Capsicum violations |
| `ParentDeathSignal` | Signal on parent termination |
| `WXMap` | W^X mapping enforcement |
| `LogSigExit` | Signal exit logging |
| `Reaper` | Process reaper for orphan adoption |
| `OOMProtection` | OOM killer protection |
| `KPTI` | Kernel page table isolation (x86_64) |
| `LinearAddress` | Linear address width (x86_64) |

---

### ACL

Swift interface to FreeBSD's POSIX.1e and NFSv4 Access Control Lists.

ACLs provide fine-grained access control beyond traditional Unix permissions, allowing you to grant specific permissions to individual users and groups.

```swift
import ACL

// Get ACL from a file
let acl = try ACL.get(path: "/path/to/file")
print("Brand: \(acl.brand)")  // .posix or .nfs4

// Check if file has extended ACL
if ACL.hasExtendedACL(path: "/path/to/file") {
    print("File has extended ACL entries")
}

// Iterate over entries
acl.forEachEntry { entry in
    print("Tag: \(entry.tag), Permissions: \(entry.permissions)")
}

// Create ACL from Unix mode
if let acl = ACL.fromMode(0o755) {
    try acl.set(path: "/path/to/file")
}

// Parse ACL from text
if let acl = ACL.fromText("user::rwx,group::r-x,other::r-x") {
    print(acl.text ?? "")
}
```

**Builder API for POSIX.1e ACLs:**

```swift
import ACL

// Build a POSIX.1e ACL programmatically
var builder = ACL.builder()
_ = builder.ownerPermissions(.all)                    // rwx for owner
_ = builder.userPermissions(1000, .readWrite)         // rw- for uid 1000
_ = builder.groupPermissions(.readExecute)            // r-x for owning group
_ = builder.groupPermissions(100, [.read])            // r-- for gid 100
_ = builder.otherPermissions([.read])                 // r-- for others

let acl = try builder.build()
try acl.set(path: "/path/to/file")
```

**NFSv4 ACLs with Allow/Deny:**

```swift
import ACL

// Build an NFSv4 ACL with allow/deny entries
var builder = ACL.nfs4Builder()
_ = builder.allowOwner(.fullSet)
_ = builder.denyUser(1000, [.writeData, .delete])
_ = builder.allowGroup(.readSet, flags: [.fileInherit, .directoryInherit])
_ = builder.allowEveryone([.readData, .readACL])

let acl = try builder.build()
try acl.set(path: "/path/to/file", type: .nfs4)
```

**Working with Entries:**

```swift
import ACL

var acl = try ACL()

// Create and configure an entry
let entry = try acl.createEntry()
try entry.setTag(.user)
try entry.setQualifier(1000)  // uid
try entry.setPermissions([.read, .write])

// For NFSv4 ACLs
try entry.setEntryType(.allow)
try entry.setNFS4Permissions([.readData, .writeData, .execute])
try entry.setFlags([.fileInherit, .directoryInherit])
```

**Permission Types:**

| POSIX.1e | NFSv4 |
|----------|-------|
| `.read` | `.readData`, `.readNamedAttrs`, `.readAttributes`, `.readACL` |
| `.write` | `.writeData`, `.appendData`, `.writeNamedAttrs`, `.writeAttributes`, `.writeACL`, `.writeOwner` |
| `.execute` | `.execute` |
| | `.delete`, `.deleteChild`, `.synchronize` |

**Tag Types:**

| Tag | Description |
|-----|-------------|
| `.userObj` | File owner |
| `.user` | Specific user (requires qualifier) |
| `.groupObj` | Owning group |
| `.group` | Specific group (requires qualifier) |
| `.mask` | Maximum group class permissions (POSIX.1e) |
| `.other` | All other users (POSIX.1e) |
| `.everyone` | All users (NFSv4) |

---

### Rctl

Swift interface to FreeBSD's rctl(4) resource control subsystem for limiting CPU, memory, and I/O resources per-process, per-user, per-jail, or per-login class.

```swift
import Rctl

// Check if rctl is enabled in the kernel
if Rctl.isEnabled {
    print("rctl is available")
}

// Get resource usage for current process
let usage = try Rctl.getCurrentProcessUsage()
print("CPU time: \(usage["cputime"] ?? "0")")
print("Memory: \(usage["memoryuse"] ?? "0")")

// Get usage for a specific subject
let jailUsage = try Rctl.getUsage(for: .jailName("myjail"))
```

**Adding Resource Limits:**

```swift
import Rctl

// Limit memory for a user to 1GB
try Rctl.limitMemory(Rctl.Size.gb(1), for: .user(1000))

// Limit CPU to 50% for a jail
try Rctl.limitCPU(50, for: .jailName("myjail"))

// Limit open files for a process
try Rctl.limitOpenFiles(256, for: .process(getpid()))

// Limit max processes per user
try Rctl.limitProcesses(100, for: .userName("www"))
```

**Custom Rules:**

```swift
import Rctl

// Create a custom rule with signal action
let rule = Rctl.Rule(
    subject: .loginClass("daemon"),
    resource: .cpuTime,
    action: .signal(SIGXCPU),
    amount: 3600  // 1 hour
)
try Rctl.addRule(rule)

// Rule with per-process limit
let memRule = Rctl.Rule(
    subject: .jail(5),
    resource: .memoryUse,
    action: .deny,
    amount: Rctl.Size.mb(512),
    per: .process
)
try Rctl.addRule(memRule)

// Remove a rule
try Rctl.removeRule(rule)

// Remove all rules for a subject
try Rctl.removeRules(for: .user(1000))
```

**Rule Builder:**

```swift
import Rctl

var builder = Rctl.ruleBuilder()
_ = builder.forSubject(.jailName("webserver"))
_ = builder.limiting(.vmemoryUse)
_ = builder.withAction(.deny)
_ = builder.toAmount(Rctl.Size.gb(4))
_ = builder.per(.process)

if let rule = builder.build() {
    try Rctl.addRule(rule)
}
```

**Query Existing Rules:**

```swift
import Rctl

// Get all rules
let allRules = try Rctl.getRules()

// Get rules for a specific subject
let userRules = try Rctl.getRules(for: .user(1000))

// Parse a rule string
if let rule = Rctl.Rule(parsing: "user:1000:memoryuse:deny=536870912/process") {
    print("Subject: \(rule.subject)")
    print("Resource: \(rule.resource)")
    print("Amount: \(rule.amount)")
}
```

**Process Descriptor Integration:**

```swift
import Rctl
import Descriptors

// Fork a child process with pdfork
let result = try ProcessCapability.fork()

if !result.isChild, var desc = result.descriptor as? ProcessCapability {
    // Get resource usage via process descriptor
    let usage = try Rctl.getUsage(for: desc)
    print("Child CPU: \(usage["cputime"] ?? "0")")

    // Or create a subject from descriptor
    let subject = try Rctl.Subject.process(from: desc)

    // Apply limits to the child process
    try Rctl.limitMemory(Rctl.Size.mb(256), for: desc)
    try Rctl.limitCPU(50, for: desc)
}
```

**Subjects:**

| Subject | Description | Example |
|---------|-------------|---------|
| `.process(pid)` | Specific process | `.process(1234)` |
| `.user(uid)` | User by UID | `.user(1000)` |
| `.userName(name)` | User by name | `.userName("www")` |
| `.loginClass(name)` | Login class | `.loginClass("daemon")` |
| `.jail(jid)` | Jail by JID | `.jail(5)` |
| `.jailName(name)` | Jail by name | `.jailName("myjail")` |

**Resources:**

| Resource | Description |
|----------|-------------|
| `.cpuTime` | CPU time in seconds |
| `.memoryUse` | Resident memory (RSS) |
| `.vmemoryUse` | Virtual memory |
| `.maxProc` | Number of processes |
| `.openFiles` | Open file descriptors |
| `.threads` | Number of threads |
| `.swapUse` | Swap space usage |
| `.pcpu` | CPU percentage (0-100 per CPU) |
| `.readBps` / `.writeBps` | I/O bandwidth |
| `.readIops` / `.writeIops` | I/O operations per second |

**Actions:**

| Action | Description |
|--------|-------------|
| `.deny` | Deny the resource allocation |
| `.log` | Log via syslog |
| `.devctl` | Send notification via devctl |
| `.throttle` | Throttle I/O (for bandwidth limits) |
| `.signal(sig)` | Send signal (SIGTERM, SIGKILL, etc.) |

---

### Cpuset

Swift interface to FreeBSD's cpuset(2) CPU affinity and NUMA domain subsystem.

```swift
import Cpuset

// Get current thread's CPU affinity
let affinity = try Cpuset.getAffinity(for: .currentThread)
print("Running on CPUs: \(affinity.cpus)")

// Get available CPUs
let available = try Cpuset.availableCPUs()
print("Available: \(available)")

// Check system CPU count
let root = try Cpuset.rootCPUs()
print("System has \(root.count) CPUs")
```

**Pinning Threads/Processes:**

```swift
import Cpuset

// Pin current thread to CPU 0
try Cpuset.pinCurrentThread(to: 0)

// Pin to multiple CPUs
try Cpuset.pinCurrentThread(to: [0, 1, 2, 3])

// Pin current process
try Cpuset.pinCurrentProcess(to: 0)

// Reset to all available CPUs
try Cpuset.resetCurrentThreadAffinity()
```

**Working with CPU Sets:**

```swift
import Cpuset

// Create CPU sets
var set = CPUSet()
set.set(cpu: 0)
set.set(cpu: 2)
set.set(cpu: 4)

// From array or range
let fromArray = CPUSet(cpus: [0, 1, 2, 3])
let fromRange = CPUSet(range: 0..<8)

// Set operations
let union = set1.union(set2)
let intersection = set1.intersection(set2)
let difference = set1.subtracting(set2)

// Query
print("CPUs: \(set.cpus)")      // [0, 2, 4]
print("Count: \(set.count)")    // 3
print("First: \(set.first!)")   // 0
print("Empty: \(set.isEmpty)")  // false
```

**NUMA Domain Affinity:**

```swift
import Cpuset

// Get domain policy
let (domains, policy) = try Cpuset.getDomain(for: .currentThread)
print("Policy: \(policy)")  // .roundRobin, .firstTouch, .prefer, .interleave

// Set first-touch allocation (local to running CPU)
try Cpuset.useFirstTouchAllocation()

// Prefer a specific domain
try Cpuset.preferDomain(0)

// Round-robin across domains
try Cpuset.useRoundRobinAllocation()

// Interleave across specific domains
try Cpuset.useInterleaveAllocation(domains: [0, 1])
```

**Process Descriptor Integration:**

```swift
import Cpuset
import Descriptors

// Fork with pdfork
let result = try ProcessCapability.fork()

if !result.isChild, let desc = result.descriptor as? ProcessCapability {
    // Pin child to specific CPUs
    try Cpuset.pin(desc, to: [0, 1])

    // Get child's affinity
    let childAffinity = try Cpuset.getAffinity(for: desc)
}
```

**Named Cpusets:**

```swift
import Cpuset

// Create a new cpuset (inherits from current)
let setId = try Cpuset.create()

// Assign thread to cpuset
try Cpuset.assign(.currentThread, to: setId)

// Get cpuset ID for a target
let id = try Cpuset.getId(level: .cpuset, for: .currentThread)
```

**IRQ and Jail Affinity:**

```swift
import Cpuset

// Get/set IRQ affinity (requires root)
let irqAffinity = try Cpuset.getIRQAffinity(16)
try Cpuset.setIRQAffinity(16, to: CPUSet(cpu: 0))

// Get/set jail affinity (requires root)
let jailAffinity = try Cpuset.getJailAffinity(5)
try Cpuset.setJailAffinity(5, to: CPUSet(cpus: [0, 1]))
```

**Targets:**

| Target | Description |
|--------|-------------|
| `.currentThread` | The calling thread |
| `.currentProcess` | The calling process |
| `.thread(tid)` | Specific thread ID |
| `.process(pid)` | Specific process ID |
| `.cpuset(id)` | Named cpuset |
| `.irq(num)` | IRQ number |
| `.jail(jid)` | Jail ID |
| `.domain(id)` | NUMA domain |

**Levels:**

| Level | Description |
|-------|-------------|
| `.root` | All system CPUs |
| `.cpuset` | Available CPUs for target's cpuset |
| `.which` | Actual mask for specific target |

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
| `CProcctl` | Process control constants and structures |
| `CACL` | ACL constants and type definitions |
| `CRctl` | Resource control syscall wrappers |
| `CCpuset` | CPU affinity macros and syscall wrappers |
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
