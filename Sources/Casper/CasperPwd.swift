/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// Password database service for Capsicum sandboxes.
///
/// `CasperPwd` wraps a Casper password service channel and provides type-safe
/// Swift interfaces to password database functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let pwd = try CasperPwd(casper: casper)
///
/// // Limit to specific users and commands
/// try pwd.limitUsers(names: ["root", "nobody"])
/// try pwd.limitCommands([.getpwnam, .getpwuid])
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Look up users
/// if let root = pwd.getpwnam("root") {
///     print("Root UID: \(root.uid)")
/// }
/// ```
public struct CasperPwd: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a password service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the password service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.pwd)
    }

    /// Creates a password service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the password service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Password service commands.
    public enum Command: String, Sendable, CaseIterable {
        case getpwent
        case getpwnam
        case getpwuid
        case getpwnam_r = "getpwnam_r"
        case getpwuid_r = "getpwuid_r"
        case setpassent
        case setpwent
        case endpwent
    }

    /// Password entry fields.
    public enum Field: String, Sendable, CaseIterable {
        case name = "pw_name"
        case passwd = "pw_passwd"
        case uid = "pw_uid"
        case gid = "pw_gid"
        case change = "pw_change"
        case `class` = "pw_class"
        case gecos = "pw_gecos"
        case dir = "pw_dir"
        case shell = "pw_shell"
        case expire = "pw_expire"
        case fields = "pw_fields"
    }

    /// Limits the password service to specific commands.
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
                    ccasper_pwd_limit_cmds(chan, ptrBuffer.baseAddress, ptrBuffer.count)
                }
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Limits the password service to return specific fields.
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
                    ccasper_pwd_limit_fields(chan, ptrBuffer.baseAddress, ptrBuffer.count)
                }
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Limits the password service to specific users.
    ///
    /// - Parameters:
    ///   - names: Usernames to allow.
    ///   - uids: User IDs to allow.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitUsers(names: [String] = [], uids: [uid_t] = []) throws {
        let nameStrings = names
        var uidArray = uids

        try nameStrings.withUnsafeBufferPointer { nameBuffer in
            var pointers = nameBuffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                try uidArray.withUnsafeMutableBufferPointer { uidBuffer in
                    let result = channel.withUnsafeChannel { chan in
                        ccasper_pwd_limit_users(
                            chan,
                            ptrBuffer.baseAddress,
                            ptrBuffer.count,
                            uidBuffer.baseAddress,
                            uidBuffer.count
                        )
                    }
                    if result != 0 {
                        throw CasperError.limitSetFailed(errno: errno)
                    }
                }
            }
        }
    }

    /// Looks up a user by name.
    ///
    /// - Parameter name: The username to look up.
    /// - Returns: Password entry, or `nil` if not found.
    public func getpwnam(_ name: String) -> PasswordEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_getpwnam(chan, namePtr)
            }
        }
        guard let pwd = result else { return nil }
        return PasswordEntry(passwd: pwd.pointee)
    }

    /// Looks up a user by UID.
    ///
    /// - Parameter uid: The user ID to look up.
    /// - Returns: Password entry, or `nil` if not found.
    public func getpwuid(_ uid: uid_t) -> PasswordEntry? {
        let result = channel.withUnsafeChannel { chan in
            ccasper_getpwuid(chan, uid)
        }
        guard let pwd = result else { return nil }
        return PasswordEntry(passwd: pwd.pointee)
    }

    /// Gets the next password entry.
    ///
    /// - Returns: Password entry, or `nil` if at end.
    public func getpwent() -> PasswordEntry? {
        let result = channel.withUnsafeChannel { chan in
            ccasper_getpwent(chan)
        }
        guard let pwd = result else { return nil }
        return PasswordEntry(passwd: pwd.pointee)
    }

    /// Rewinds the password entry enumeration.
    public func setpwent() {
        channel.withUnsafeChannel { chan in
            ccasper_setpwent(chan)
        }
    }

    /// Ends the password entry enumeration.
    public func endpwent() {
        channel.withUnsafeChannel { chan in
            ccasper_endpwent(chan)
        }
    }
}

/// A password database entry.
public struct PasswordEntry: Sendable {
    /// Username.
    public let name: String
    /// Encrypted password.
    public let passwd: String
    /// User ID.
    public let uid: uid_t
    /// Group ID.
    public let gid: gid_t
    /// Password change time.
    public let change: time_t
    /// User access class.
    public let `class`: String
    /// User's real name or comment.
    public let gecos: String
    /// Home directory.
    public let dir: String
    /// Login shell.
    public let shell: String
    /// Account expiration time.
    public let expire: time_t

    init(passwd: Glibc.passwd) {
        self.name = String(cString: passwd.pw_name)
        self.passwd = String(cString: passwd.pw_passwd)
        self.uid = passwd.pw_uid
        self.gid = passwd.pw_gid
        self.change = passwd.pw_change
        self.class = String(cString: passwd.pw_class)
        self.gecos = String(cString: passwd.pw_gecos)
        self.dir = String(cString: passwd.pw_dir)
        self.shell = String(cString: passwd.pw_shell)
        self.expire = passwd.pw_expire
    }
}
