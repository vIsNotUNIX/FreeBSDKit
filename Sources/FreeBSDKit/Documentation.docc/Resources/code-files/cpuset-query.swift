import Cpuset
import Glibc

// Get current CPU affinity
let mask = try Cpuset.getAffinity(pid: getpid())

print("Current CPU affinity:")
for cpu in 0..<64 {
    if mask.isSet(cpu: cpu) {
        print("  CPU \(cpu): enabled")
    }
}
