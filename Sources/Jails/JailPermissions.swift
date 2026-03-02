/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import FreeBSDKit

/// Permissions for a jail (allow.* parameters).
///
/// These control what privileged operations are allowed inside the jail.
/// By default, jails are restricted; permissions must be explicitly granted.
///
/// ## Usage
///
/// ```swift
/// var perms = JailPermissions()
///
/// // Basic permissions
/// perms.allowSetHostname = true
/// perms.allowRawSockets = true
/// perms.allowChflags = true
///
/// // Mount permissions
/// perms.allowMount(.devfs)
/// perms.allowMount(.tmpfs)
/// perms.allowMount(.procfs)
///
/// // Apply to configuration
/// var config = JailConfiguration(name: "test", path: "/jail/test")
/// config.permissions = perms
/// ```
public struct JailPermissions: Sendable, Equatable {

    // MARK: - Basic Permissions

    /// Allow changing the jail's hostname.
    public var allowSetHostname: Bool = false

    /// Allow System V IPC primitives (shared memory, semaphores, message queues).
    public var allowSysvipc: Bool = false

    /// Allow raw socket access (required for ping, traceroute, etc.).
    public var allowRawSockets: Bool = false

    /// Allow changing file flags with chflags(1).
    public var allowChflags: Bool = false

    /// Allow filesystem quotas.
    public var allowQuotas: Bool = false

    /// Allow access to other address families (e.g., Bluetooth).
    public var allowSocketAf: Bool = false

    /// Allow mlock/mlockall for memory locking.
    public var allowMlock: Bool = false

    /// Allow binding to reserved ports (<1024).
    public var allowReservedPorts: Bool = false

    /// Allow reading the kernel message buffer.
    public var allowReadMsgbuf: Bool = false

    /// Allow unprivileged process debugging.
    public var allowUnprivilegedProcDebug: Bool = false

    /// Allow unprivileged parent tampering.
    public var allowUnprivilegedParentTampering: Bool = false

    /// Allow root privileges inside jail (default: true in FreeBSD).
    public var allowSuser: Bool = true

    /// Allow NFS server operations.
    public var allowNfsd: Bool = false

    /// Allow modifying extended attributes.
    public var allowExtattr: Bool = false

    /// Allow adjusting system time with adjtime(2).
    public var allowAdjtime: Bool = false

    /// Allow setting system time with settimeofday(2).
    public var allowSettime: Bool = false

    /// Allow routing operations.
    public var allowRouting: Bool = false

    /// Allow audit control operations.
    public var allowSetaudit: Bool = false

    // MARK: - Mount Permissions

    /// Filesystem types that can be mounted.
    public var mountPermissions: Set<MountType> = []

    /// Filesystem types that can be mounted inside a jail.
    public enum MountType: String, Sendable, CaseIterable {
        case devfs
        case procfs
        case tmpfs
        case fdescfs
        case linprocfs
        case linsysfs
        case lindebugfs
        case zfs
    }

    /// Allow mounting a specific filesystem type.
    public mutating func allowMount(_ type: MountType) {
        mountPermissions.insert(type)
    }

    /// Disallow mounting a specific filesystem type.
    public mutating func disallowMount(_ type: MountType) {
        mountPermissions.remove(type)
    }

    /// Allow mounting any filesystem (enable general mount permission).
    public var allowMountAny: Bool = false

    // MARK: - ZFS Permissions

    /// Allow mounting ZFS snapshots.
    public var allowZfsMountSnapshot: Bool = false

    // MARK: - Initialization

    /// Creates default permissions (all disabled except suser).
    public init() {}

    /// Creates permissions with common development settings.
    public static var development: JailPermissions {
        var perms = JailPermissions()
        perms.allowSetHostname = true
        perms.allowRawSockets = true
        perms.allowSysvipc = true
        perms.allowMount(.devfs)
        perms.allowMount(.procfs)
        perms.allowMount(.tmpfs)
        perms.allowUnprivilegedProcDebug = true
        return perms
    }

    /// Creates permissions for a web server jail.
    public static var webServer: JailPermissions {
        var perms = JailPermissions()
        perms.allowReservedPorts = true
        perms.allowMount(.devfs)
        return perms
    }

    /// Creates restrictive permissions (everything disabled).
    public static var restrictive: JailPermissions {
        var perms = JailPermissions()
        perms.allowSuser = false
        return perms
    }

    // MARK: - IOVector Population

    /// Populates the permissions into a JailIOVector.
    internal func populate(into iov: JailIOVector) throws {
        // Only add parameters that differ from FreeBSD defaults
        // FreeBSD defaults: allow.set_hostname=1, allow.sysvipc=0, etc.

        if allowSetHostname {
            try iov.addBool("allow.set_hostname", true)
        }
        if allowSysvipc {
            try iov.addBool("allow.sysvipc", true)
        }
        if allowRawSockets {
            try iov.addBool("allow.raw_sockets", true)
        }
        if allowChflags {
            try iov.addBool("allow.chflags", true)
        }
        if allowQuotas {
            try iov.addBool("allow.quotas", true)
        }
        if allowSocketAf {
            try iov.addBool("allow.socket_af", true)
        }
        if allowMlock {
            try iov.addBool("allow.mlock", true)
        }
        if allowReservedPorts {
            try iov.addBool("allow.reserved_ports", true)
        }
        if allowReadMsgbuf {
            try iov.addBool("allow.read_msgbuf", true)
        }
        if allowUnprivilegedProcDebug {
            try iov.addBool("allow.unprivileged_proc_debug", true)
        }
        if allowUnprivilegedParentTampering {
            try iov.addBool("allow.unprivileged_parent_tampering", true)
        }
        if !allowSuser {
            try iov.addBool("allow.suser", false)
        }
        if allowNfsd {
            try iov.addBool("allow.nfsd", true)
        }
        if allowExtattr {
            try iov.addBool("allow.extattr", true)
        }
        if allowAdjtime {
            try iov.addBool("allow.adjtime", true)
        }
        if allowSettime {
            try iov.addBool("allow.settime", true)
        }
        if allowRouting {
            try iov.addBool("allow.routing", true)
        }
        if allowSetaudit {
            try iov.addBool("allow.setaudit", true)
        }

        // Mount permissions
        if allowMountAny {
            try iov.addBool("allow.mount", true)
        }
        for mountType in mountPermissions {
            try iov.addBool("allow.mount.\(mountType.rawValue)", true)
        }

        // ZFS
        if allowZfsMountSnapshot {
            try iov.addBool("zfs.mount_snapshot", true)
        }
    }
}

// MARK: - ExpressibleByArrayLiteral

extension JailPermissions: ExpressibleByArrayLiteral {
    /// Creates permissions from an array of permission keys.
    ///
    /// ```swift
    /// let perms: JailPermissions = [.rawSockets, .sysvipc, .mount(.devfs)]
    /// ```
    public init(arrayLiteral elements: Permission...) {
        self.init()
        for element in elements {
            apply(element)
        }
    }

    /// A permission that can be applied to a jail.
    public enum Permission: Sendable {
        case setHostname
        case sysvipc
        case rawSockets
        case chflags
        case quotas
        case socketAf
        case mlock
        case reservedPorts
        case readMsgbuf
        case unprivilegedProcDebug
        case unprivilegedParentTampering
        case noSuser
        case nfsd
        case extattr
        case adjtime
        case settime
        case routing
        case setaudit
        case mount(MountType)
        case mountAny
        case zfsMountSnapshot
    }

    private mutating func apply(_ permission: Permission) {
        switch permission {
        case .setHostname: allowSetHostname = true
        case .sysvipc: allowSysvipc = true
        case .rawSockets: allowRawSockets = true
        case .chflags: allowChflags = true
        case .quotas: allowQuotas = true
        case .socketAf: allowSocketAf = true
        case .mlock: allowMlock = true
        case .reservedPorts: allowReservedPorts = true
        case .readMsgbuf: allowReadMsgbuf = true
        case .unprivilegedProcDebug: allowUnprivilegedProcDebug = true
        case .unprivilegedParentTampering: allowUnprivilegedParentTampering = true
        case .noSuser: allowSuser = false
        case .nfsd: allowNfsd = true
        case .extattr: allowExtattr = true
        case .adjtime: allowAdjtime = true
        case .settime: allowSettime = true
        case .routing: allowRouting = true
        case .setaudit: allowSetaudit = true
        case .mount(let type): mountPermissions.insert(type)
        case .mountAny: allowMountAny = true
        case .zfsMountSnapshot: allowZfsMountSnapshot = true
        }
    }
}
