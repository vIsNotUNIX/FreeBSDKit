/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// Network database service for Capsicum sandboxes.
///
/// `CasperNetdb` wraps a Casper netdb service channel and provides type-safe
/// Swift interfaces to network database functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let netdb = try CasperNetdb(casper: casper)
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Look up protocol information
/// if let tcp = netdb.protocol(named: "tcp") {
///     print("TCP protocol number: \(tcp.proto)")
/// }
/// ```
public struct CasperNetdb: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a netdb service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the netdb service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.netdb)
    }

    /// Creates a netdb service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the netdb service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Looks up a protocol by name.
    ///
    /// - Parameter named: The protocol name (e.g., "tcp", "udp", "icmp").
    /// - Returns: Protocol entry, or `nil` if not found.
    public func `protocol`(named name: String) -> ProtocolEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_netdb_getprotobyname(chan, namePtr)
            }
        }
        guard let proto = result else { return nil }
        return ProtocolEntry(protoent: proto.pointee)
    }
}

/// A protocol database entry.
public struct ProtocolEntry: Sendable {
    /// The official protocol name.
    public let name: String
    /// Alias names for the protocol.
    public let aliases: [String]
    /// The protocol number.
    public let proto: Int32

    init(protoent: protoent) {
        self.name = String(cString: protoent.p_name)
        self.proto = protoent.p_proto

        var aliases: [String] = []
        if var ptr = protoent.p_aliases {
            while let alias = ptr.pointee {
                aliases.append(String(cString: alias))
                ptr += 1
            }
        }
        self.aliases = aliases
    }
}
