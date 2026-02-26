import Procctl
import Glibc

// Get current ASLR status
let aslr = try Procctl.getASLR(pid: getpid())
print("ASLR status: \(aslr)")

// Disable ASLR for current process (affects children)
try Procctl.setASLR(pid: getpid(), enabled: false)
print("ASLR disabled")

// Re-enable ASLR
try Procctl.setASLR(pid: getpid(), enabled: true)
print("ASLR enabled")
