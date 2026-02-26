import Capsicum

// Common capability rights
let rights: [(String, CapabilityRights)] = [
    // Basic I/O
    ("CAP_READ", .read),
    ("CAP_WRITE", .write),
    ("CAP_SEEK", .seek),
    ("CAP_PREAD", .pread),
    ("CAP_PWRITE", .pwrite),

    // Memory mapping
    ("CAP_MMAP", .mmap),
    ("CAP_MMAP_R", .mmapRead),
    ("CAP_MMAP_W", .mmapWrite),
    ("CAP_MMAP_X", .mmapExecute),

    // File operations
    ("CAP_FSTAT", .fstat),
    ("CAP_FCHMOD", .fchmod),
    ("CAP_FCHOWN", .fchown),
    ("CAP_FTRUNCATE", .ftruncate),
    ("CAP_FSYNC", .fsync),

    // Directory operations
    ("CAP_LOOKUP", .lookup),
    ("CAP_CREATE", .create),
    ("CAP_UNLINKAT", .unlinkat),
    ("CAP_MKDIRAT", .mkdirat),
    ("CAP_RENAMEAT_SOURCE", .renameatSource),
    ("CAP_RENAMEAT_TARGET", .renameatTarget),

    // Sockets
    ("CAP_ACCEPT", .accept),
    ("CAP_BIND", .bind),
    ("CAP_CONNECT", .connect),
    ("CAP_LISTEN", .listen),
    ("CAP_GETPEERNAME", .getpeername),
    ("CAP_GETSOCKNAME", .getsockname),
]

for (name, _) in rights {
    print(name)
}
