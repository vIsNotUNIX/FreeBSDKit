import Cpuset
import Glibc

// Pin the current process to CPUs 0 and 1
var mask = Cpuset.Mask()
mask.set(cpu: 0)
mask.set(cpu: 1)

try Cpuset.setAffinity(pid: getpid(), mask: mask)

print("Process pinned to CPUs 0 and 1")
