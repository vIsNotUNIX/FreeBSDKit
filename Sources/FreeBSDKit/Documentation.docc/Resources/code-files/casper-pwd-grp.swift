import Casper
import Capsicum
import Glibc

// Create password and group services
let casper = try Casper()
let pwd = try casper.service(.pwd)
let grp = try casper.service(.grp)

// Limit to specific users/groups or fields
try pwd.limit(fields: ["pw_name", "pw_uid", "pw_gid", "pw_dir"])
try grp.limit(fields: ["gr_name", "gr_gid", "gr_mem"])

// Enter capability mode
try Capsicum.enterCapabilityMode()

// Look up the current user
let uid = getuid()
if let user = try pwd.getpwuid(uid) {
    print("Username: \(user.name)")
    print("UID: \(user.uid)")
    print("GID: \(user.gid)")
    print("Home: \(user.homeDirectory)")
}

// Look up a user by name
if let root = try pwd.getpwnam("root") {
    print("\nRoot user:")
    print("  UID: \(root.uid)")
    print("  Home: \(root.homeDirectory)")
}

// Look up a group
if let wheel = try grp.getgrnam("wheel") {
    print("\nWheel group:")
    print("  GID: \(wheel.gid)")
    print("  Members: \(wheel.members.joined(separator: ", "))")
}
