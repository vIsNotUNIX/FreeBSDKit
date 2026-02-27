/*
 * ACL Get/Set/Iterate Example
 */

import ACL
import Glibc

let testFile = "/tmp/acl_test_\(getpid())"

// Create a test file
let fd = open(testFile, O_CREAT | O_WRONLY, 0o644)
close(fd)
defer { unlink(testFile) }

print("=== GET: Read ACL from file ===\n")

let acl = try ACL(contentsOf: testFile, type: .nfs4)
print("Brand: \(acl.brand)")
print("Is trivial: \(acl.isTrivial)")

print("\n=== ITERATE: Loop through entries ===\n")

for entry in acl.entries {
    print("Tag: \(entry.tag)")

    if let qualifier = entry.qualifier {
        print("  Qualifier (uid/gid): \(qualifier)")
    }

    if let entryType = entry.entryType {
        print("  Type: \(entryType)")  // allow/deny for NFSv4
    }

    // POSIX.1e permissions
    print("  Permissions: \(entry.permissions)")

    // NFSv4 permissions (more detailed)
    let nfs4 = entry.nfs4Permissions
    if !nfs4.isEmpty {
        print("  NFSv4 perms: ", terminator: "")
        if nfs4.contains(.readData) { print("read ", terminator: "") }
        if nfs4.contains(.writeData) { print("write ", terminator: "") }
        if nfs4.contains(.execute) { print("exec ", terminator: "") }
        if nfs4.contains(.delete) { print("delete ", terminator: "") }
        print()
    }

    // NFSv4 inheritance flags
    let flags = entry.flags
    if !flags.isEmpty {
        print("  Flags: ", terminator: "")
        if flags.contains(.fileInherit) { print("file_inherit ", terminator: "") }
        if flags.contains(.directoryInherit) { print("dir_inherit ", terminator: "") }
        print()
    }

    print()
}

print("=== SET: Apply new ACL to file ===\n")

// Build a new NFSv4 ACL
var builder = ACL.nfs4Builder()
_ = builder.allowOwner(.fullSet)
_ = builder.allowGroup([.readData, .execute, .readAttributes, .readACL])
_ = builder.allowEveryone([.readData, .readACL])

let newACL = try builder.build()

// Apply it
try newACL.apply(to: testFile, type: .nfs4)
print("Applied new ACL")

print("\n=== VERIFY: Read back and iterate ===\n")

let verify = try ACL(contentsOf: testFile, type: .nfs4)
for entry in verify.entries {
    let typeStr = entry.entryType == .allow ? "ALLOW" : "DENY"
    print("\(typeStr) \(entry.tag)")
}

print("\n=== TEXT OUTPUT ===\n")
if let text = verify.text {
    print(text)
}
