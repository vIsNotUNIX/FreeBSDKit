/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// Group database service for Capsicum sandboxes.
///
/// `CasperGrp` wraps a Casper group service channel and provides type-safe
/// Swift interfaces to group database functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let grp = try CasperGrp(casper: casper)
///
/// // Limit to specific groups
/// try grp.limitGroups(names: ["wheel", "operator"])
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Look up groups
/// if let wheel = grp.getgrnam("wheel") {
///     print("Wheel GID: \(wheel.gid)")
/// }
/// ```
public struct CasperGrp: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a group service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the group service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.grp)
    }

    /// Creates a group service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the group service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Group service commands.
    public enum Command: String, Sendable, CaseIterable {
        case getgrent
        case getgrnam
        case getgrgid
        case getgrnam_r = "getgrnam_r"
        case getgrgid_r = "getgrgid_r"
        case setgroupent
        case setgrent
        case endgrent
    }

    /// Group entry fields.
    public enum Field: String, Sendable, CaseIterable {
        case name = "gr_name"
        case passwd = "gr_passwd"
        case gid = "gr_gid"
        case mem = "gr_mem"
    }

    /// Limits the group service to specific commands.
    ///
    /// - Parameter commands: The allowed commands.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitCommands(_ commands: [Command]) throws {
        let cmdStrings = commands.map { $0.rawValue }
        try cmdStrings.withUnsafeBufferPointer { buffer in
            var pointers = buffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                let result = channel.withUnsafeChannel { chan in
                    ccasper_grp_limit_cmds(chan, ptrBuffer.baseAddress, ptrBuffer.count)
                }
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Limits the group service to return specific fields.
    ///
    /// - Parameter fields: The fields to return.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitFields(_ fields: [Field]) throws {
        let fieldStrings = fields.map { $0.rawValue }
        try fieldStrings.withUnsafeBufferPointer { buffer in
            var pointers = buffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                let result = channel.withUnsafeChannel { chan in
                    ccasper_grp_limit_fields(chan, ptrBuffer.baseAddress, ptrBuffer.count)
                }
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Limits the group service to specific groups.
    ///
    /// - Parameters:
    ///   - names: Group names to allow.
    ///   - gids: Group IDs to allow.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitGroups(names: [String] = [], gids: [gid_t] = []) throws {
        let nameStrings = names
        var gidArray = gids

        try nameStrings.withUnsafeBufferPointer { nameBuffer in
            var pointers = nameBuffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                try gidArray.withUnsafeMutableBufferPointer { gidBuffer in
                    let result = channel.withUnsafeChannel { chan in
                        ccasper_grp_limit_groups(
                            chan,
                            ptrBuffer.baseAddress,
                            ptrBuffer.count,
                            gidBuffer.baseAddress,
                            gidBuffer.count
                        )
                    }
                    if result != 0 {
                        throw CasperError.limitSetFailed(errno: errno)
                    }
                }
            }
        }
    }

    /// Looks up a group by name.
    ///
    /// - Parameter name: The group name to look up.
    /// - Returns: Group entry, or `nil` if not found.
    public func getgrnam(_ name: String) -> GroupEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_getgrnam(chan, namePtr)
            }
        }
        guard let grp = result else { return nil }
        return GroupEntry(group: grp.pointee)
    }

    /// Looks up a group by GID.
    ///
    /// - Parameter gid: The group ID to look up.
    /// - Returns: Group entry, or `nil` if not found.
    public func getgrgid(_ gid: gid_t) -> GroupEntry? {
        let result = channel.withUnsafeChannel { chan in
            ccasper_getgrgid(chan, gid)
        }
        guard let grp = result else { return nil }
        return GroupEntry(group: grp.pointee)
    }

    /// Gets the next group entry.
    ///
    /// - Returns: Group entry, or `nil` if at end.
    public func getgrent() -> GroupEntry? {
        let result = channel.withUnsafeChannel { chan in
            ccasper_getgrent(chan)
        }
        guard let grp = result else { return nil }
        return GroupEntry(group: grp.pointee)
    }

    /// Rewinds the group entry enumeration.
    public func setgrent() {
        channel.withUnsafeChannel { chan in
            ccasper_setgrent(chan)
        }
    }

    /// Ends the group entry enumeration.
    public func endgrent() {
        channel.withUnsafeChannel { chan in
            ccasper_endgrent(chan)
        }
    }
}

/// A group database entry.
public struct GroupEntry: Sendable {
    /// Group name.
    public let name: String
    /// Encrypted password.
    public let passwd: String
    /// Group ID.
    public let gid: gid_t
    /// Group members.
    public let members: [String]

    init(group: Glibc.group) {
        self.name = String(cString: group.gr_name)
        self.passwd = String(cString: group.gr_passwd)
        self.gid = group.gr_gid

        var members: [String] = []
        if var ptr = group.gr_mem {
            while let member = ptr.pointee {
                members.append(String(cString: member))
                ptr += 1
            }
        }
        self.members = members
    }
}
