import Audit

let pipe = try Audit.Pipe()

// Create a mask for specific event classes
var mask = Audit.Mask()

// Add classes for successful events
mask.success = [
    .fileRead,      // fr - File read
    .fileWrite,     // fw - File write
    .fileCreate,    // fc - File create
    .fileDelete,    // fd - File delete
    .fileClose,     // cl - File close
    .process,       // pc - Process operations
    .network,       // nt - Network events
    .login,         // lo - Login/logout
    .admin,         // ad - Administrative
]

// Add classes for failed events
mask.failure = [
    .fileRead,
    .fileWrite,
    .login,         // Failed login attempts
]

// Apply the mask
try pipe.set(preselectionMask: mask)
try pipe.set(preselectionMode: .local)

print("Filtering configured for file and login events")
