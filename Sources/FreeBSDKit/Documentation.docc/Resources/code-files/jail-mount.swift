import Jails

var params = JailParameters()
params.name = "mounting"
params.path = "/jails/mounting"

// Allow mounting specific filesystem types
params.allowMount = true            // Enable mount operations
params.allowMountDevfs = true       // Allow devfs (for /dev)
params.allowMountProcfs = true      // Allow procfs (for /proc)
params.allowMountNullfs = true      // Allow nullfs (bind mounts)
params.allowMountTmpfs = true       // Allow tmpfs (memory filesystem)

// ZFS permissions (requires allow.mount.zfs sysctl)
params.allowMountZfs = false        // Allow ZFS (powerful, use carefully)

// Enforce mount restrictions
params.enforceStatfs = 2            // Hide other mounts
                                    // 0: See all mounts
                                    // 1: See jail's mounts
                                    // 2: Only see jail's mounts, paths hidden

let jid = try Jail.create(parameters: params)
