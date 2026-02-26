import Casper
import Capsicum

// Create sysctl service before sandboxing
let casper = try Casper()
let sysctl = try casper.service(.sysctl)

// Limit to specific sysctl names (security!)
try sysctl.limit(names: [
    "kern.hostname",
    "kern.ostype",
    "kern.osrelease",
    "hw.ncpu",
    "hw.physmem"
])

// Enter capability mode
try Capsicum.enterCapabilityMode()

// Read sysctl values from within sandbox
let hostname = try sysctl.string(name: "kern.hostname")
print("Hostname: \(hostname)")

let osType = try sysctl.string(name: "kern.ostype")
let osRelease = try sysctl.string(name: "kern.osrelease")
print("OS: \(osType) \(osRelease)")

let ncpu = try sysctl.int(name: "hw.ncpu")
print("CPUs: \(ncpu)")

let physmem = try sysctl.uint64(name: "hw.physmem")
print("Physical memory: \(physmem / 1024 / 1024) MB")
