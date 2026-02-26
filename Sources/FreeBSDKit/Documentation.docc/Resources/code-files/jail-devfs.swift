import Jails
import Foundation

// devfs rules control which devices are visible in /dev
// First, set up the jail's devfs

func setupJailDevfs(jailPath: String, ruleset: Int32) throws {
    let devPath = "\(jailPath)/dev"

    // Create /dev directory
    try FileManager.default.createDirectory(
        atPath: devPath,
        withIntermediateDirectories: true
    )

    // Mount devfs
    // mount -t devfs devfs /jails/myjail/dev

    // Apply ruleset
    // devfs -m /jails/myjail/dev rule -s <ruleset> applyset

    // Common rulesets:
    // 1: Hide all devices
    // 2: Unhide null, zero, random
    // 3: Unhide pty devices
    // 4: Unhide basic devices for jail
}

// Jail configuration
var params = JailParameters()
params.name = "devfs_jail"
params.path = "/jails/devfs_jail"
params.allowMountDevfs = true

// devfs.ruleset controls which ruleset to apply
params.devfsRuleset = 4  // Standard jail ruleset

let jid = try Jail.create(parameters: params)
