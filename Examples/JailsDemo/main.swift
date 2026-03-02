/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Jails Demo - Demonstrates the FreeBSDKit Jails API
 *
 * This example shows how to:
 * - List existing jails
 * - Create jails with various configurations
 * - Query jail information
 * - Remove jails
 * - Use jail descriptors
 *
 * Usage: sudo jails-demo [command]
 *
 * Commands:
 *   list          - List all active jails
 *   info <name>   - Show info for a specific jail
 *   create        - Create a demo jail
 *   remove <name> - Remove a jail
 *   demo          - Run full demonstration
 *   desc-demo     - Demonstrate descriptor-based API
 */

import Jails
import Descriptors
import Foundation
import Glibc

// MARK: - Main

@main
struct JailsDemo {
    static func main() {
        let args = CommandLine.arguments

        // Check if running as root
        if getuid() != 0 {
            print("Warning: Most jail operations require root privileges")
            print("Run with: sudo \(args[0])")
            print()
        }

        let command = args.count > 1 ? args[1] : "help"

        do {
            switch command {
            case "list":
                try listJails()

            case "info":
                guard args.count > 2 else {
                    print("Usage: \(args[0]) info <jail-name>")
                    return
                }
                try showJailInfo(name: args[2])

            case "create":
                try createDemoJail()

            case "remove":
                guard args.count > 2 else {
                    print("Usage: \(args[0]) remove <jail-name>")
                    return
                }
                try removeJail(name: args[2])

            case "demo":
                try runFullDemo()

            case "desc-demo":
                try runDescriptorDemo()

            case "status":
                showCurrentStatus()

            case "help", "-h", "--help":
                printHelp()

            default:
                print("Unknown command: \(command)")
                printHelp()
            }
        } catch {
            print("Error: \(error)")
        }
    }

    // MARK: - Commands

    static func printHelp() {
        print("""
        Jails Demo - FreeBSDKit Jails API Demonstration

        Usage: jails-demo <command> [args]

        Commands:
          list              List all active jails
          info <name>       Show detailed info for a jail
          create            Create a demo jail (requires root)
          remove <name>     Remove a jail by name (requires root)
          demo              Run full demonstration (requires root)
          desc-demo         Demonstrate descriptor-based API (requires root)
          status            Show current jail status
          help              Show this help message

        Examples:
          sudo jails-demo list
          sudo jails-demo create
          sudo jails-demo info demo-jail
          sudo jails-demo remove demo-jail
          sudo jails-demo demo
          sudo jails-demo desc-demo
        """)
    }

    static func showCurrentStatus() {
        print("=== Current Jail Status ===")
        print()

        let jid = Jail.currentJid()
        if Jail.isJailed {
            print("Running INSIDE jail with JID: \(jid)")
        } else {
            print("Running OUTSIDE any jail (host system)")
        }
        print()
    }

    static func listJails() throws {
        print("=== Active Jails ===")
        print()

        let jails = try Jail.list()

        if jails.isEmpty {
            print("No active jails found.")
            print()
            print("Tip: Create a jail with 'sudo jails-demo create'")
            return
        }

        // Print header
        print("JID\tNAME\t\t\tHOSTNAME\t\t\tPATH")
        print(String(repeating: "-", count: 80))

        for jail in jails {
            print("\(jail.jid)\t\(jail.name)\t\(jail.hostname)\t\(jail.path)")
        }

        print()
        print("Total: \(jails.count) jail(s)")
    }

    static func showJailInfo(name: String) throws {
        print("=== Jail Info: \(name) ===")
        print()

        guard let info = try Jail.find(name: name) else {
            print("Jail '\(name)' not found.")
            print()
            print("Use 'jails-demo list' to see active jails.")
            return
        }

        print("JID:      \(info.jid)")
        print("Name:     \(info.name)")
        print("Path:     \(info.path)")
        print("Hostname: \(info.hostname)")
    }

    static func createDemoJail() throws {
        let jailName = "freebsdkit-demo"
        let jailPath = "/tmp/jail-demo"

        print("=== Creating Demo Jail ===")
        print()

        // Check if jail already exists
        if let existing = try Jail.find(name: jailName) {
            print("Jail '\(jailName)' already exists (JID: \(existing.jid))")
            print("Remove it with: sudo jails-demo remove \(jailName)")
            return
        }

        // Create the jail filesystem
        print("Creating jail filesystem: \(jailPath)")
        try createMinimalJailFS(at: jailPath)

        // Create a simple configuration
        print("Creating jail configuration...")
        var config = JailConfiguration(name: jailName, path: jailPath)
        config.hostname = "demo.jail.local"
        config.persist = true  // Keep jail alive even when empty

        // Set some permissions
        config.permissions.allowSetHostname = true
        config.permissions.allowRawSockets = false
        config.permissions.allowMount(.devfs)

        print()
        print("Configuration:")
        print("  Name:     \(config.name)")
        print("  Path:     \(config.path)")
        print("  Hostname: \(config.hostname ?? "none")")
        print("  Persist:  \(config.persist)")
        print()

        // Create the jail
        print("Creating jail...")
        let handle = try Jail.create(config)

        print()
        print("Jail created successfully!")
        print("  JID: \(handle.jid)")
        print("  Name: \(handle.name ?? jailName)")
        print()
        print("To see the jail: jls")
        print("To remove:       sudo jails-demo remove \(jailName)")
    }

    static func removeJail(name: String) throws {
        print("=== Removing Jail: \(name) ===")
        print()

        // Check if jail exists
        guard let info = try Jail.find(name: name) else {
            print("Jail '\(name)' not found.")
            return
        }

        print("Found jail:")
        print("  JID:  \(info.jid)")
        print("  Path: \(info.path)")
        print()

        print("Removing jail...")
        try Jail.remove(jid: info.jid)

        print("Jail '\(name)' removed successfully!")

        // Optionally clean up the directory
        if info.path.hasPrefix("/tmp/") {
            print()
            print("Cleaning up jail directory: \(info.path)")
            try? FileManager.default.removeItem(atPath: info.path)
        }
    }

    static func runFullDemo() throws {
        print("=== FreeBSDKit Jails API Demo ===")
        print()

        // 1. Show current status
        showCurrentStatus()

        // 2. List existing jails
        print("--- Listing existing jails ---")
        try listJails()
        print()

        // 3. Create demo jails with different configurations
        print("--- Creating demo jails ---")
        print()

        let basePath = "/tmp/jails-demo"
        try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)

        // Create a basic jail
        try createJailWithConfig(
            name: "demo-basic",
            path: "\(basePath)/basic",
            description: "Basic jail with minimal configuration"
        ) { config in
            config.hostname = "basic.demo"
            config.persist = true
        }

        // Create a development jail
        try createJailWithConfig(
            name: "demo-dev",
            path: "\(basePath)/dev",
            description: "Development jail with more permissions"
        ) { config in
            config.hostname = "dev.demo"
            config.persist = true
            config.permissions = .development
        }

        // Create a web server jail
        try createJailWithConfig(
            name: "demo-web",
            path: "\(basePath)/web",
            description: "Web server jail"
        ) { config in
            config.hostname = "web.demo"
            config.persist = true
            config.permissions = .webServer
            config.permissions.allowRawSockets = true  // For health checks
        }

        print()
        print("--- Listing jails after creation ---")
        try listJails()
        print()

        // 4. Query jail information
        print("--- Querying jail information ---")
        print()

        for name in ["demo-basic", "demo-dev", "demo-web"] {
            if let info = try Jail.find(name: name) {
                print("\(info.name):")
                print("  JID: \(info.jid), Host: \(info.hostname)")
            }
        }
        print()

        // 5. Clean up
        print("--- Cleaning up demo jails ---")
        print()

        for name in ["demo-basic", "demo-dev", "demo-web"] {
            if let _ = try Jail.find(name: name) {
                try Jail.remove(name: name)
                print("Removed: \(name)")
            }
        }

        // Remove demo directory
        try? FileManager.default.removeItem(atPath: basePath)
        print()

        print("--- Final jail list ---")
        try listJails()
        print()

        print("Demo completed successfully!")
    }

    /// Demonstrates the descriptor-based jail API.
    ///
    /// Jail descriptors provide file-descriptor-based handles to jails,
    /// which can be useful for:
    /// - Passing jail references between processes
    /// - Auto-cleanup of jails when descriptors close (owning descriptors)
    /// - Capability-mode compatible jail operations
    static func runDescriptorDemo() throws {
        print("=== Jail Descriptor API Demo ===")
        print()

        let jailPath = "/tmp/jail-desc-demo"
        let jailName = "desc-demo"

        // Create jail filesystem
        print("1. Creating jail filesystem at \(jailPath)...")
        try createMinimalJailFS(at: jailPath)

        // Create jail using descriptor API
        print("2. Creating jail with owning descriptor...")
        var config = JailConfiguration(name: jailName, path: jailPath)
        config.hostname = "desc-demo.local"
        config.persist = true

        let descriptor = try SystemJailDescriptor.create(config)
        print("   Created jail with owning descriptor")

        // Query jail info through descriptor
        print("3. Querying jail info through descriptor...")
        if let info = try descriptor.info() {
            print("   JID:      \(info.jid)")
            print("   Name:     \(info.name)")
            print("   Path:     \(info.path)")
            print("   Hostname: \(info.hostname)")
        }

        // Open another (non-owning) descriptor to the same jail
        print()
        print("4. Opening non-owning descriptor by name...")
        let descriptor2 = try SystemJailDescriptor.open(name: jailName, owning: false)
        if let info = try descriptor2.info() {
            print("   Successfully opened descriptor for JID \(info.jid)")
        }
        descriptor2.close()
        print("   Closed non-owning descriptor")

        // Remove jail using descriptor
        print()
        print("5. Removing jail using descriptor...")
        try descriptor.remove()
        print("   Jail removed successfully!")

        // Clean up filesystem
        print()
        print("6. Cleaning up jail filesystem...")
        try? FileManager.default.removeItem(atPath: jailPath)

        // Close the descriptor (no-op after remove, but good practice)
        descriptor.close()

        print()
        print("Descriptor demo completed successfully!")
        print()
        print("Key benefits of jail descriptors:")
        print("  - File descriptors can be passed between processes")
        print("  - Owning descriptors auto-remove jails when closed")
        print("  - Compatible with Capsicum capability mode")
        print("  - Operations work even if jail name changes")
    }

    // MARK: - Helpers

    static func createJailWithConfig(
        name: String,
        path: String,
        description: String,
        configure: (inout JailConfiguration) -> Void
    ) throws {
        print("Creating '\(name)' - \(description)")

        // Create a proper jail root filesystem structure
        try createMinimalJailFS(at: path)

        // Configure
        var config = JailConfiguration(name: name, path: path)
        configure(&config)

        // Create
        let handle = try Jail.create(config)
        print("  Created with JID: \(handle.jid)")
    }

    /// Creates a minimal filesystem structure for a jail.
    /// For a real jail, you'd use `bsdinstall jail` or extract a base tarball.
    static func createMinimalJailFS(at path: String) throws {
        let fm = FileManager.default

        // Create essential directories
        let dirs = [
            "",          // root
            "bin",
            "dev",
            "etc",
            "lib",
            "libexec",
            "sbin",
            "tmp",
            "usr",
            "usr/bin",
            "usr/lib",
            "usr/sbin",
            "usr/share",
            "var",
            "var/log",
            "var/run",
            "var/tmp"
        ]

        for dir in dirs {
            let fullPath = path + "/" + dir
            try? fm.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
        }

        // Set proper permissions on tmp directories
        chmod(path + "/tmp", 0o1777)
        chmod(path + "/var/tmp", 0o1777)

        // Create minimal /etc files
        let etcPath = path + "/etc"

        // /etc/passwd
        let passwd = "root:*:0:0:Charlie &:/root:/bin/sh\nnobody:*:65534:65534:Unprivileged user:/nonexistent:/usr/sbin/nologin\n"
        try? passwd.write(toFile: etcPath + "/passwd", atomically: true, encoding: .utf8)

        // /etc/group
        let group = "wheel:*:0:root\nnogroup:*:65533:\nnobody:*:65534:\n"
        try? group.write(toFile: etcPath + "/group", atomically: true, encoding: .utf8)

        // /etc/master.passwd
        let masterPasswd = "root:*:0:0::0:0:Charlie &:/root:/bin/sh\nnobody:*:65534:65534::0:0:Unprivileged user:/nonexistent:/usr/sbin/nologin\n"
        try? masterPasswd.write(toFile: etcPath + "/master.passwd", atomically: true, encoding: .utf8)
        chmod(etcPath + "/master.passwd", 0o600)

        // /etc/rc.conf (empty but required)
        try? "".write(toFile: etcPath + "/rc.conf", atomically: true, encoding: .utf8)

        // /etc/resolv.conf (copy from host for DNS)
        if fm.fileExists(atPath: "/etc/resolv.conf") {
            try? fm.copyItem(atPath: "/etc/resolv.conf", toPath: etcPath + "/resolv.conf")
        }

        // Copy essential binaries (if they exist on host)
        // This is minimal - a real jail would need more
        let binaries = [
            ("/bin/sh", "/bin/sh"),
            ("/usr/bin/true", "/usr/bin/true"),
            ("/usr/bin/env", "/usr/bin/env")
        ]

        for (src, dst) in binaries {
            let dstPath = path + dst
            if fm.fileExists(atPath: src) && !fm.fileExists(atPath: dstPath) {
                try? fm.copyItem(atPath: src, toPath: dstPath)
            }
        }

        // Copy required shared libraries for /bin/sh
        // This is a simplified approach - real jails need proper library resolution
        let libs = [
            "/lib/libc.so.7",
            "/lib/libedit.so.8",
            "/lib/libncursesw.so.9",
            "/libexec/ld-elf.so.1"
        ]

        for lib in libs {
            let dstPath = path + lib
            if fm.fileExists(atPath: lib) && !fm.fileExists(atPath: dstPath) {
                try? fm.copyItem(atPath: lib, toPath: dstPath)
            }
        }
    }
}

// MARK: - Permission Display

extension JailPermissions {
    var summary: String {
        var enabled: [String] = []
        if allowSetHostname { enabled.append("set_hostname") }
        if allowRawSockets { enabled.append("raw_sockets") }
        if allowSysvipc { enabled.append("sysvipc") }
        if allowChflags { enabled.append("chflags") }
        if allowMlock { enabled.append("mlock") }
        if allowReservedPorts { enabled.append("reserved_ports") }
        if !mountPermissions.isEmpty {
            enabled.append("mount(\(mountPermissions.map(\.rawValue).joined(separator: ",")))")
        }
        return enabled.isEmpty ? "none" : enabled.joined(separator: ", ")
    }
}
