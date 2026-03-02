/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CJails
import FreeBSDKit
import Glibc

/// High-level interface to FreeBSD jails.
///
/// The `Jail` namespace provides convenient methods for creating, querying,
/// and managing jails without dealing with low-level `JailIOVector` construction.
///
/// ## Creating a Jail
///
/// ```swift
/// // Simple jail creation
/// let jail = try Jail.create(
///     name: "myjail",
///     path: "/jail/myjail",
///     hostname: "myjail.local"
/// )
///
/// // With configuration
/// var config = JailConfiguration(name: "webserver", path: "/jail/web")
/// config.hostname = "web.local"
/// config.persist = true
/// config.permissions.allowRawSockets = true
/// config.permissions.allowMount(.devfs)
/// let jail = try Jail.create(config)
/// ```
///
/// ## Querying Jails
///
/// ```swift
/// // List all jails
/// let jails = try Jail.list()
/// for info in jails {
///     print("\(info.name): jid=\(info.jid), path=\(info.path)")
/// }
///
/// // Find by name
/// if let info = try Jail.find(name: "myjail") {
///     print("Found jail: \(info.jid)")
/// }
///
/// // Find by JID
/// if let info = try Jail.find(jid: 5) {
///     print("Found jail: \(info.name)")
/// }
/// ```
///
/// ## Working with Jail Descriptors
///
/// ```swift
/// // Get a descriptor for an existing jail
/// let desc = try Jail.open(name: "myjail")
///
/// // Attach current process to jail
/// try desc.attach()
///
/// // Remove jail (requires owning descriptor)
/// let owned = try Jail.open(name: "myjail", owning: true)
/// try owned.remove()
/// ```
public enum Jail {

    // MARK: - Create

    /// Creates a new jail with the specified configuration.
    ///
    /// - Parameters:
    ///   - config: The jail configuration.
    ///   - shouldAttach: If true, attach the calling process to the jail.
    /// - Returns: A jail handle for the created jail.
    /// - Throws: `BSDError` if jail creation fails.
    public static func create(
        _ config: JailConfiguration,
        attach shouldAttach: Bool = false
    ) throws -> JailHandle {
        let iov = JailIOVector()
        try config.populate(into: iov)

        var flags: JailSetFlags = [.create]
        if shouldAttach {
            flags.insert(.attach)
        }

        let jid = try iov.withUnsafeMutableIOVecs { buf in
            let result = jail_set(buf.baseAddress, UInt32(buf.count), flags.rawValue)
            if result < 0 {
                try BSDError.throwErrno(errno)
            }
            return result
        }

        return JailHandle(jid: jid, name: config.name, owning: true)
    }

    /// Creates a new jail with minimal configuration.
    ///
    /// - Parameters:
    ///   - name: The jail name.
    ///   - path: The root path for the jail's filesystem.
    ///   - hostname: Optional hostname (defaults to name).
    ///   - persist: If true, jail persists even when empty.
    ///   - shouldAttach: If true, attach the calling process to the jail.
    /// - Returns: A jail handle for the created jail.
    /// - Throws: `BSDError` if jail creation fails.
    public static func create(
        name: String,
        path: String,
        hostname: String? = nil,
        persist: Bool = false,
        attach shouldAttach: Bool = false
    ) throws -> JailHandle {
        var config = JailConfiguration(name: name, path: path)
        config.hostname = hostname ?? name
        config.persist = persist
        return try create(config, attach: shouldAttach)
    }

    // MARK: - Update

    /// Updates an existing jail's configuration.
    ///
    /// - Parameters:
    ///   - name: The name of the jail to update.
    ///   - config: The new configuration values.
    /// - Throws: `BSDError` if the update fails.
    public static func update(name: String, with config: JailConfiguration) throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: name)
        try config.populateUpdates(into: iov)

        let flags: JailSetFlags = [.update]

        try iov.withUnsafeMutableIOVecs { buf in
            let result = jail_set(buf.baseAddress, UInt32(buf.count), flags.rawValue)
            if result < 0 {
                try BSDError.throwErrno(errno)
            }
        }
    }

    // MARK: - Open

    /// Opens a jail descriptor for an existing jail.
    ///
    /// - Parameters:
    ///   - name: The jail name.
    ///   - owning: If true, request an owning descriptor (can remove jail).
    /// - Returns: A jail handle.
    /// - Throws: `BSDError` if the jail doesn't exist or can't be opened.
    public static func open(name: String, owning: Bool = false) throws -> JailHandle {
        let iov = JailIOVector()
        try iov.addCString("name", value: name)

        var flags: JailGetFlags = [.getDesc]
        if owning {
            flags.insert(.ownDesc)
        }

        let jid = try iov.withUnsafeMutableIOVecs { buf in
            let result = jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
            if result < 0 {
                try BSDError.throwErrno(errno)
            }
            return result
        }

        return JailHandle(jid: jid, name: name, owning: owning)
    }

    /// Opens a jail descriptor for an existing jail by JID.
    ///
    /// - Parameters:
    ///   - jid: The jail ID.
    ///   - owning: If true, request an owning descriptor (can remove jail).
    /// - Returns: A jail handle.
    /// - Throws: `BSDError` if the jail doesn't exist or can't be opened.
    public static func open(jid: Int32, owning: Bool = false) throws -> JailHandle {
        let iov = JailIOVector()
        try iov.addInt32("jid", jid)

        var flags: JailGetFlags = [.getDesc]
        if owning {
            flags.insert(.ownDesc)
        }

        let result = try iov.withUnsafeMutableIOVecs { buf in
            let r = jail_get(buf.baseAddress, UInt32(buf.count), flags.rawValue)
            if r < 0 {
                try BSDError.throwErrno(errno)
            }
            return r
        }

        return JailHandle(jid: result, name: nil, owning: owning)
    }

    // MARK: - Query

    /// Finds a jail by name.
    ///
    /// - Parameter name: The jail name.
    /// - Returns: Jail info if found, nil otherwise.
    public static func find(name: String) throws -> JailInfo? {
        let iov = JailIOVector()
        try iov.addCString("name", value: name)

        // Add output buffers
        let pathBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
        defer { pathBuf.deallocate() }
        pathBuf.initialize(repeating: 0, count: 1024)

        let hostnameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { hostnameBuf.deallocate() }
        hostnameBuf.initialize(repeating: 0, count: 256)

        try iov.addOutputBuffer("path", buffer: pathBuf, size: 1024)
        try iov.addOutputBuffer("host.hostname", buffer: hostnameBuf, size: 256)

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), 0)
        }

        if jid < 0 {
            if errno == ENOENT {
                return nil
            }
            try BSDError.throwErrno(errno)
        }

        return JailInfo(
            jid: jid,
            name: name,
            path: String(cString: pathBuf),
            hostname: String(cString: hostnameBuf)
        )
    }

    /// Finds a jail by JID.
    ///
    /// - Parameter jid: The jail ID.
    /// - Returns: Jail info if found, nil otherwise.
    public static func find(jid: Int32) throws -> JailInfo? {
        let iov = JailIOVector()
        try iov.addInt32("jid", jid)

        // Add output buffers
        let nameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { nameBuf.deallocate() }
        nameBuf.initialize(repeating: 0, count: 256)

        let pathBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
        defer { pathBuf.deallocate() }
        pathBuf.initialize(repeating: 0, count: 1024)

        let hostnameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { hostnameBuf.deallocate() }
        hostnameBuf.initialize(repeating: 0, count: 256)

        try iov.addOutputBuffer("name", buffer: nameBuf, size: 256)
        try iov.addOutputBuffer("path", buffer: pathBuf, size: 1024)
        try iov.addOutputBuffer("host.hostname", buffer: hostnameBuf, size: 256)

        let result = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), 0)
        }

        if result < 0 {
            if errno == ENOENT {
                return nil
            }
            try BSDError.throwErrno(errno)
        }

        return JailInfo(
            jid: result,
            name: String(cString: nameBuf),
            path: String(cString: pathBuf),
            hostname: String(cString: hostnameBuf)
        )
    }

    /// Lists all active jails.
    ///
    /// - Parameter includeDying: If true, include jails that are shutting down.
    /// - Returns: Array of jail info for all jails.
    public static func list(includeDying: Bool = false) throws -> [JailInfo] {
        var jails: [JailInfo] = []
        var lastJid: Int32 = 0

        while true {
            let iov = JailIOVector()
            try iov.addInt32("lastjid", lastJid)

            // Add output buffers
            let nameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
            defer { nameBuf.deallocate() }
            nameBuf.initialize(repeating: 0, count: 256)

            let pathBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
            defer { pathBuf.deallocate() }
            pathBuf.initialize(repeating: 0, count: 1024)

            let hostnameBuf = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
            defer { hostnameBuf.deallocate() }
            hostnameBuf.initialize(repeating: 0, count: 256)

            try iov.addOutputBuffer("name", buffer: nameBuf, size: 256)
            try iov.addOutputBuffer("path", buffer: pathBuf, size: 1024)
            try iov.addOutputBuffer("host.hostname", buffer: hostnameBuf, size: 256)

            var flags: Int32 = 0
            if includeDying {
                flags |= JAIL_DYING
            }

            let jid = iov.withUnsafeMutableIOVecs { buf in
                jail_get(buf.baseAddress, UInt32(buf.count), flags)
            }

            if jid < 0 {
                if errno == ENOENT {
                    break  // No more jails
                }
                try BSDError.throwErrno(errno)
            }

            jails.append(JailInfo(
                jid: jid,
                name: String(cString: nameBuf),
                path: String(cString: pathBuf),
                hostname: String(cString: hostnameBuf)
            ))

            lastJid = jid
        }

        return jails
    }

    // MARK: - Remove

    /// Removes a jail by name.
    ///
    /// - Parameter name: The jail name.
    /// - Throws: `BSDError` if removal fails.
    public static func remove(name: String) throws {
        let jid = try findJid(name: name)
        guard jail_remove(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    /// Removes a jail by JID.
    ///
    /// - Parameter jid: The jail ID.
    /// - Throws: `BSDError` if removal fails.
    public static func remove(jid: Int32) throws {
        guard jail_remove(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    // MARK: - Attach

    /// Attaches the current process to a jail by name.
    ///
    /// - Parameter name: The jail name.
    /// - Throws: `BSDError` if attachment fails.
    /// - Warning: This is irreversible for the current process.
    public static func attach(name: String) throws {
        let jid = try findJid(name: name)
        guard jail_attach(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    /// Attaches the current process to a jail by JID.
    ///
    /// - Parameter jid: The jail ID.
    /// - Throws: `BSDError` if attachment fails.
    /// - Warning: This is irreversible for the current process.
    public static func attach(jid: Int32) throws {
        guard jail_attach(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    // MARK: - Current Jail

    /// Returns the JID of the current process's jail.
    ///
    /// - Returns: 0 if not in a jail, otherwise the JID.
    public static func currentJid() -> Int32 {
        // Use jail_get with jid=0 to query current jail
        let iov = JailIOVector()
        do {
            try iov.addInt32("jid", 0)
        } catch {
            return 0
        }

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), 0)
        }

        // Returns -1 with ENOENT if not in a jail
        return jid > 0 ? jid : 0
    }

    /// Returns true if the current process is inside a jail.
    public static var isJailed: Bool {
        currentJid() > 0
    }

    // MARK: - Private Helpers

    private static func findJid(name: String) throws -> Int32 {
        let iov = JailIOVector()
        try iov.addCString("name", value: name)

        let jid = iov.withUnsafeMutableIOVecs { buf in
            jail_get(buf.baseAddress, UInt32(buf.count), 0)
        }

        if jid < 0 {
            try BSDError.throwErrno(errno)
        }

        return jid
    }
}

// MARK: - JailInfo

/// Information about an existing jail.
public struct JailInfo: Sendable, Equatable {
    /// The jail ID.
    public let jid: Int32

    /// The jail name.
    public let name: String

    /// The root path of the jail's filesystem.
    public let path: String

    /// The jail's hostname.
    public let hostname: String

    public init(jid: Int32, name: String, path: String, hostname: String) {
        self.jid = jid
        self.name = name
        self.path = path
        self.hostname = hostname
    }
}

extension JailInfo: CustomStringConvertible {
    public var description: String {
        "Jail(\(jid): \(name) at \(path))"
    }
}

// MARK: - JailHandle

/// A handle to a jail that can perform operations on it.
///
/// Unlike `SystemJailDescriptor`, `JailHandle` uses JID-based operations
/// which don't require managing file descriptors.
///
/// ## Usage
///
/// ```swift
/// let handle = try Jail.create(name: "myjail", path: "/jail/myjail")
/// print("Created jail with JID: \(handle.jid)")
///
/// // Later, remove the jail
/// try handle.remove()
/// ```
public struct JailHandle: Sendable {
    /// The jail ID.
    public let jid: Int32

    /// The jail name (if known).
    public let name: String?

    /// Whether this handle has ownership (can remove the jail).
    public let isOwning: Bool

    internal init(jid: Int32, name: String?, owning: Bool) {
        self.jid = jid
        self.name = name
        self.isOwning = owning
    }

    /// Attaches the current process to this jail.
    ///
    /// - Throws: `BSDError` if attachment fails.
    /// - Warning: This is irreversible for the current process.
    public func attach() throws {
        guard jail_attach(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    /// Removes this jail.
    ///
    /// - Throws: `BSDError` if removal fails.
    /// - Note: Requires an owning handle.
    public func remove() throws {
        guard jail_remove(jid) == 0 else {
            try BSDError.throwErrno(errno)
        }
    }

    /// Gets current information about this jail.
    ///
    /// - Returns: Jail info, or nil if the jail no longer exists.
    public func info() throws -> JailInfo? {
        try Jail.find(jid: jid)
    }
}

extension JailHandle: CustomStringConvertible {
    public var description: String {
        if let name = name {
            return "JailHandle(\(jid): \(name), isOwning: \(isOwning))"
        }
        return "JailHandle(\(jid), isOwning: \(isOwning))"
    }
}
