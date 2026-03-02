/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Descriptors
import FreeBSDKit

// MARK: - PeerCredentials

/// Credentials of a peer connected via Unix domain socket.
///
/// On FreeBSD, credentials are retrieved using the `LOCAL_PEERCRED` socket option,
/// which returns an `xucred` structure containing the peer's **effective** credentials.
///
/// ## Available Fields
///
/// From `LOCAL_PEERCRED` (`xucred` structure):
/// - `uid`: Effective user ID
/// - `gid`: Effective group ID (first element of groups array)
/// - `pid`: Process ID (FreeBSD 13.0+)
/// - `groups`: Up to 16 groups (effective GID + supplementary groups)
///
/// ## Credential Capture Timing
///
/// - For servers: Credentials are captured when the client calls `connect(2)`
/// - For clients: Credentials are captured when the server calls `listen(2)`
///
/// This mechanism is reliable - neither party can manipulate the credentials
/// except through making the appropriate system calls under different effective
/// credentials.
///
/// ## Note on Real vs Effective Credentials
///
/// `LOCAL_PEERCRED` only provides **effective** credentials (euid/egid).
/// To obtain real credentials (ruid/rgid), use `LOCAL_CREDS_PERSISTENT` which
/// delivers a `sockcred2` structure via `recvmsg()` control messages.
/// For most authorization purposes, effective credentials are what matter.
///
/// ## Usage
///
/// ```swift
/// // Server side - after accepting a connection
/// let listener = try FPCListener.listen(on: "/tmp/my.sock")
/// await listener.start()
/// let endpoint = try await listener.accept()
/// let creds = try endpoint.getPeerCredentials()
/// print("Client UID: \(creds.uid), GID: \(creds.gid), PID: \(creds.pid)")
/// ```
public struct PeerCredentials: Sendable, Equatable, Hashable {
    /// The effective user ID of the peer process.
    ///
    /// This is the euid, not the real uid. For most authorization purposes,
    /// the effective UID is what determines the process's current privileges.
    public let uid: uid_t

    /// The effective group ID of the peer process.
    ///
    /// This is the egid (first element of the groups array), not the real gid.
    public let gid: gid_t

    /// The process ID of the peer process.
    ///
    /// Note: This field is only available on FreeBSD 13.0 and later.
    /// On older systems, this may be 0.
    public let pid: pid_t

    /// The number of groups (including effective GID).
    ///
    /// This count includes the effective GID as the first element,
    /// so supplementary groups count is `groupCount - 1`.
    public let groupCount: Int

    /// All groups of the peer process.
    ///
    /// The first element is the effective GID (same as `gid`).
    /// Elements 1 through `groupCount-1` are supplementary groups.
    /// Maximum of 16 groups (XU_NGROUPS).
    public let groups: [gid_t]

    /// The supplementary groups (excluding the effective GID).
    ///
    /// This is a convenience accessor that returns `groups` without
    /// the first element (effective GID).
    public var supplementaryGroups: [gid_t] {
        groups.count > 1 ? Array(groups.dropFirst()) : []
    }

    /// Creates a new `PeerCredentials` instance.
    public init(uid: uid_t, gid: gid_t, pid: pid_t = 0, groups: [gid_t] = []) {
        self.uid = uid
        self.gid = gid
        self.pid = pid
        self.groupCount = groups.count
        self.groups = groups
    }

    /// Creates a `PeerCredentials` instance from an `xucred` structure.
    internal init(from creds: xucred) {
        self.uid = creds.cr_uid
        self.pid = creds.cr_pid

        // cr_ngroups includes the effective GID at position 0
        let ngroups = Int(creds.cr_ngroups)
        self.groupCount = ngroups

        // Extract all groups from the cr_groups array
        var groupList: [gid_t] = []
        if ngroups > 0 {
            // The effective GID is at cr_groups[0] (aliased as cr_gid in the union)
            self.gid = creds.cr_groups.0
            groupList.append(creds.cr_groups.0)

            // Add remaining groups (supplementary)
            if ngroups > 1 {
                withUnsafeBytes(of: creds.cr_groups) { ptr in
                    let gids = ptr.bindMemory(to: gid_t.self)
                    for i in 1..<min(ngroups, Int(XU_NGROUPS)) {
                        groupList.append(gids[i])
                    }
                }
            }
        } else {
            self.gid = 0
        }
        self.groups = groupList
    }

    /// Checks if this peer is running as root (effective UID 0).
    public var isRoot: Bool {
        uid == 0
    }

    /// Checks if the peer is a member of the specified group.
    ///
    /// This checks the effective GID and all supplementary groups.
    ///
    /// - Parameter group: The group ID to check membership for.
    /// - Returns: `true` if the peer is a member of the group.
    public func isMemberOf(group: gid_t) -> Bool {
        groups.contains(group)
    }

    /// Checks if the peer is a member of the wheel group (GID 0).
    ///
    /// On FreeBSD, the wheel group typically grants sudo/su access.
    public var isWheelMember: Bool {
        isMemberOf(group: 0)
    }
}

// MARK: - CustomStringConvertible

extension PeerCredentials: CustomStringConvertible {
    public var description: String {
        "PeerCredentials(uid: \(uid), gid: \(gid), pid: \(pid))"
    }
}

// MARK: - SocketDescriptor Extension

public extension SocketDescriptor where Self: ~Copyable {
    /// Gets the credentials of the peer connected to this Unix domain socket.
    ///
    /// Uses the `LOCAL_PEERCRED` socket option to retrieve the peer's credentials.
    /// This only works on connected Unix domain sockets (`SOCK_STREAM` or `SOCK_SEQPACKET`).
    ///
    /// - Returns: The credentials of the connected peer.
    /// - Throws: A BSD error if the credentials cannot be retrieved.
    func getPeerCredentials() throws -> PeerCredentials {
        try self.unsafe { fd in
            var creds = xucred()
            var len = socklen_t(MemoryLayout<xucred>.size)

            guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERCRED, &creds, &len) == 0 else {
                try BSDError.throwErrno(errno)
            }

            // Verify the structure version
            guard creds.cr_version == XUCRED_VERSION else {
                throw FPCError.invalidMessageFormat
            }

            return PeerCredentials(from: creds)
        }
    }
}
