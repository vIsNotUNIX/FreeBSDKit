/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CJails
import FreeBSDKit
import Glibc

/// Configuration for creating or updating a jail.
///
/// `JailConfiguration` provides a type-safe way to specify jail parameters
/// without dealing with low-level `iovec` construction.
///
/// ## Basic Usage
///
/// ```swift
/// var config = JailConfiguration(name: "webserver", path: "/jail/web")
/// config.hostname = "web.local"
/// config.persist = true
/// config.securelevel = 2
///
/// let jail = try Jail.create(config)
/// ```
///
/// ## Network Configuration
///
/// ```swift
/// var config = JailConfiguration(name: "netjail", path: "/jail/net")
/// config.vnet = true  // Virtual network stack
/// // OR for IP-based jails:
/// config.ip4Addresses = ["192.168.1.100", "192.168.1.101"]
/// config.ip6Addresses = ["::1"]
/// ```
///
/// ## Permissions
///
/// ```swift
/// var config = JailConfiguration(name: "devjail", path: "/jail/dev")
/// config.permissions.allowRawSockets = true
/// config.permissions.allowChflags = true
/// config.permissions.allowMount(.devfs)
/// config.permissions.allowMount(.tmpfs)
/// ```
public struct JailConfiguration: Sendable {

    // MARK: - Required Parameters

    /// The jail name (required).
    public var name: String

    /// The root path for the jail's filesystem (required).
    public var path: String

    // MARK: - Host Identity

    /// The jail's hostname.
    public var hostname: String?

    /// The jail's NIS domain name.
    public var domainname: String?

    /// The jail's host UUID.
    public var hostuuid: String?

    /// The jail's host ID (like hostid(1)).
    public var hostid: UInt32?

    // MARK: - Persistence & Limits

    /// If true, the jail persists even when no processes are running.
    public var persist: Bool = false

    /// Maximum number of child jails allowed.
    public var childrenMax: Int32?

    /// The jail's securelevel (see security(7)).
    public var securelevel: Int32?

    /// Devfs ruleset number to apply.
    public var devfsRuleset: Int32?

    /// Controls visibility of mount points (0, 1, or 2).
    public var enforceStatfs: Int32?

    // MARK: - OS Emulation

    /// Override the reported OS release string.
    public var osrelease: String?

    /// Override the reported OS release date.
    public var osreldate: Int32?

    // MARK: - Network

    /// If true, create a virtual network stack for this jail.
    public var vnet: Bool = false

    /// IPv4 addresses assigned to this jail.
    public var ip4Addresses: [String] = []

    /// IPv6 addresses assigned to this jail.
    public var ip6Addresses: [String] = []

    /// If true, prefer jail's own address for source address selection.
    public var ip4SourceAddressSelection: Bool = true

    /// If true, prefer jail's own address for IPv6 source address selection.
    public var ip6SourceAddressSelection: Bool = true

    // MARK: - Permissions

    /// Jail permissions (allow.* parameters).
    public var permissions: JailPermissions = JailPermissions()

    // MARK: - Linux Emulation

    /// Linux emulation OS name.
    public var linuxOsname: String?

    /// Linux emulation OS release.
    public var linuxOsrelease: String?

    /// Linux emulation OSS version.
    public var linuxOssVersion: Int32?

    // MARK: - CPU Affinity

    /// Cpuset ID to assign to the jail.
    public var cpusetId: Int32?

    // MARK: - Initialization

    /// Creates a jail configuration with required parameters.
    ///
    /// - Parameters:
    ///   - name: The jail name.
    ///   - path: The root filesystem path.
    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }

    // MARK: - IOVector Population

    /// Populates a JailIOVector with this configuration.
    public func populate(into iov: JailIOVector) throws {
        // Required
        try iov.addCString("name", value: name)
        try iov.addCString("path", value: path)

        // Host identity
        if let hostname = hostname {
            try iov.addCString("host.hostname", value: hostname)
        }
        if let domainname = domainname {
            try iov.addCString("host.domainname", value: domainname)
        }
        if let hostuuid = hostuuid {
            try iov.addCString("host.hostuuid", value: hostuuid)
        }
        if let hostid = hostid {
            try iov.addUInt32("host.hostid", hostid)
        }

        // Persistence
        if persist {
            try iov.addBool("persist", true)
        }
        if let childrenMax = childrenMax {
            try iov.addInt32("children.max", childrenMax)
        }
        if let securelevel = securelevel {
            try iov.addInt32("securelevel", securelevel)
        }
        if let devfsRuleset = devfsRuleset {
            try iov.addInt32("devfs_ruleset", devfsRuleset)
        }
        if let enforceStatfs = enforceStatfs {
            try iov.addInt32("enforce_statfs", enforceStatfs)
        }

        // OS emulation
        if let osrelease = osrelease {
            try iov.addCString("osrelease", value: osrelease)
        }
        if let osreldate = osreldate {
            try iov.addInt32("osreldate", osreldate)
        }

        // Network
        if vnet {
            try iov.addBool("vnet", true)
        }

        if !ip4Addresses.isEmpty {
            // IP addresses are passed as "ip4.addr" with multiple values
            // For simplicity, join as comma-separated
            try iov.addCString("ip4.addr", value: ip4Addresses.joined(separator: ","))
        }

        if !ip6Addresses.isEmpty {
            try iov.addCString("ip6.addr", value: ip6Addresses.joined(separator: ","))
        }

        if !ip4SourceAddressSelection {
            try iov.addBool("ip4.saddrsel", false)
        }
        if !ip6SourceAddressSelection {
            try iov.addBool("ip6.saddrsel", false)
        }

        // Linux emulation
        if let linuxOsname = linuxOsname {
            try iov.addCString("linux.osname", value: linuxOsname)
        }
        if let linuxOsrelease = linuxOsrelease {
            try iov.addCString("linux.osrelease", value: linuxOsrelease)
        }
        if let linuxOssVersion = linuxOssVersion {
            try iov.addInt32("linux.oss_version", linuxOssVersion)
        }

        // CPU affinity
        if let cpusetId = cpusetId {
            try iov.addInt32("cpuset.id", cpusetId)
        }

        // Permissions
        try permissions.populate(into: iov)
    }

    /// Populates only the update-specific parameters.
    internal func populateUpdates(into iov: JailIOVector) throws {
        // For updates, we can change most parameters except name/path
        if let hostname = hostname {
            try iov.addCString("host.hostname", value: hostname)
        }
        if let domainname = domainname {
            try iov.addCString("host.domainname", value: domainname)
        }
        if let securelevel = securelevel {
            try iov.addInt32("securelevel", securelevel)
        }
        if let childrenMax = childrenMax {
            try iov.addInt32("children.max", childrenMax)
        }

        // Persist can be toggled
        try iov.addBool("persist", persist)

        // Network updates
        if !ip4Addresses.isEmpty {
            try iov.addCString("ip4.addr", value: ip4Addresses.joined(separator: ","))
        }
        if !ip6Addresses.isEmpty {
            try iov.addCString("ip6.addr", value: ip6Addresses.joined(separator: ","))
        }

        // Permissions can be updated
        try permissions.populate(into: iov)
    }
}

// MARK: - Convenience Builders

extension JailConfiguration {

    /// Creates a minimal persistent jail configuration.
    public static func persistent(name: String, path: String) -> JailConfiguration {
        var config = JailConfiguration(name: name, path: path)
        config.persist = true
        return config
    }

    /// Creates a VNET jail configuration with its own network stack.
    public static func vnet(name: String, path: String) -> JailConfiguration {
        var config = JailConfiguration(name: name, path: path)
        config.vnet = true
        return config
    }

    /// Creates a configuration for a Linux-compatible jail.
    public static func linux(
        name: String,
        path: String,
        osname: String = "Linux",
        osrelease: String = "5.15.0"
    ) -> JailConfiguration {
        var config = JailConfiguration(name: name, path: path)
        config.linuxOsname = osname
        config.linuxOsrelease = osrelease
        return config
    }
}
