import Jails

var params = JailParameters()
params.name = "restricted"
params.path = "/jails/restricted"

// Control specific operations

// Networking
params.allowRawSockets = false      // No ICMP, raw IP
params.allowSocket6 = true          // Allow IPv6 sockets
params.allowSocket4 = true          // Allow IPv4 sockets

// Filesystem
params.allowMount = false           // No mounting filesystems
params.allowMountDevfs = false      // No devfs mounts
params.allowMountNullfs = false     // No nullfs mounts
params.allowMountProcfs = false     // No procfs mounts
params.allowMountZfs = false        // No ZFS mounts
params.allowQuotas = false          // No disk quotas

// System
params.allowSetHostname = false     // Cannot change hostname
params.allowSysvipc = false         // No System V IPC
params.allowChflags = false         // No chflags

// Jails
params.allowJails = false           // Cannot create child jails

let jid = try Jail.create(parameters: params)
print("Created restricted jail")
