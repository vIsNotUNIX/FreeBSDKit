/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Foundation
import Glibc

/// DNS resolution service for Capsicum sandboxes.
///
/// `CasperDNS` wraps a Casper DNS service channel and provides type-safe
/// Swift interfaces to DNS resolution functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let dns = try CasperDNS(casper: casper)
///
/// // Limit to only forward lookups
/// try dns.limit(types: [.nameToAddress])
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Resolve hostname
/// let addresses = try dns.getaddrinfo(hostname: "example.com", port: "443")
/// ```
public struct CasperDNS: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a DNS service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the DNS service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.dns)
    }

    /// Creates a DNS service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the DNS service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// DNS lookup type for limiting service operations.
    public enum LookupType: String, Sendable {
        /// Forward lookup (hostname to address).
        case nameToAddress = "NAME2ADDR"
        /// Reverse lookup (address to hostname).
        case addressToName = "ADDR2NAME"
    }

    /// Limits the DNS service to specific lookup types.
    ///
    /// - Parameter types: The allowed lookup types.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limit(types: [LookupType]) throws {
        let typeStrings = types.map { $0.rawValue }
        try typeStrings.withUnsafeBufferPointer { buffer in
            var pointers = buffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                let result = channel.withUnsafeChannel { chan in
                    ccasper_dns_type_limit(chan, ptrBuffer.baseAddress, ptrBuffer.count)
                }
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Limits the DNS service to specific address families.
    ///
    /// - Parameter families: The allowed address families (e.g., AF_INET, AF_INET6).
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limit(families: [Int32]) throws {
        var fams = families
        let result = fams.withUnsafeMutableBufferPointer { buffer in
            channel.withUnsafeChannel { chan in
                ccasper_dns_family_limit(chan, buffer.baseAddress, buffer.count)
            }
        }
        if result != 0 {
            throw CasperError.limitSetFailed(errno: errno)
        }
    }

    /// Resolves a hostname to addresses.
    ///
    /// This is the Swift wrapper around `getaddrinfo`.
    ///
    /// - Parameters:
    ///   - hostname: The hostname to resolve.
    ///   - port: The service name or port number (optional).
    ///   - family: Address family (AF_UNSPEC for any, AF_INET for IPv4, AF_INET6 for IPv6).
    ///   - socktype: Socket type (SOCK_STREAM, SOCK_DGRAM, etc.).
    ///   - flags: Additional flags for `getaddrinfo`.
    /// - Returns: Array of resolved addresses.
    /// - Throws: `CasperError.operationFailed` if resolution fails.
    public func getaddrinfo(
        hostname: String,
        port: String? = nil,
        family: Int32 = AF_UNSPEC,
        socktype: Int32 = 0,
        flags: Int32 = 0
    ) throws -> [ResolvedAddress] {
        var hints = addrinfo()
        hints.ai_family = family
        hints.ai_socktype = socktype
        hints.ai_flags = flags

        var result: UnsafeMutablePointer<addrinfo>?

        let err = hostname.withCString { hostnamePtr in
            if let port = port {
                return port.withCString { portPtr in
                    channel.withUnsafeChannel { chan in
                        ccasper_getaddrinfo(chan, hostnamePtr, portPtr, &hints, &result)
                    }
                }
            } else {
                return channel.withUnsafeChannel { chan in
                    ccasper_getaddrinfo(chan, hostnamePtr, nil, &hints, &result)
                }
            }
        }

        guard err == 0 else {
            throw CasperError.operationFailed(errno: err)
        }

        defer { freeaddrinfo(result) }

        var addresses: [ResolvedAddress] = []
        var current = result

        while let info = current {
            if let addr = ResolvedAddress(addrinfo: info.pointee) {
                addresses.append(addr)
            }
            current = info.pointee.ai_next
        }

        return addresses
    }

    /// Performs a reverse DNS lookup.
    ///
    /// - Parameters:
    ///   - address: The socket address to look up.
    ///   - flags: Flags for `getnameinfo`.
    /// - Returns: A tuple of (hostname, service name).
    /// - Throws: `CasperError.operationFailed` if lookup fails.
    public func getnameinfo(
        address: UnsafePointer<sockaddr>,
        length: socklen_t,
        flags: Int32 = 0
    ) throws -> (hostname: String, service: String) {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var serv = [CChar](repeating: 0, count: Int(NI_MAXSERV))

        let err = channel.withUnsafeChannel { chan in
            ccasper_getnameinfo(
                chan,
                address,
                length,
                &host,
                host.count,
                &serv,
                serv.count,
                flags
            )
        }

        guard err == 0 else {
            throw CasperError.operationFailed(errno: err)
        }

        return (String(cString: host), String(cString: serv))
    }

    /// Resolves a hostname using the legacy `gethostbyname` interface.
    ///
    /// - Parameter name: The hostname to resolve.
    /// - Returns: Host information, or `nil` if not found.
    public func gethostbyname(_ name: String) -> HostEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_gethostbyname(chan, namePtr)
            }
        }
        guard let hostent = result else { return nil }
        return HostEntry(hostent: hostent.pointee)
    }

    /// Resolves a hostname with a specific address family.
    ///
    /// - Parameters:
    ///   - name: The hostname to resolve.
    ///   - family: The address family (AF_INET or AF_INET6).
    /// - Returns: Host information, or `nil` if not found.
    public func gethostbyname2(_ name: String, family: Int32) -> HostEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_gethostbyname2(chan, namePtr, family)
            }
        }
        guard let hostent = result else { return nil }
        return HostEntry(hostent: hostent.pointee)
    }
}

/// A resolved network address from DNS lookup.
public struct ResolvedAddress: Sendable {
    /// The address family (AF_INET or AF_INET6).
    public let family: Int32
    /// The socket type (SOCK_STREAM, SOCK_DGRAM, etc.).
    public let socktype: Int32
    /// The protocol.
    public let `protocol`: Int32
    /// The canonical name, if available.
    public let canonicalName: String?
    /// The raw socket address data.
    public let addressData: Data

    init?(addrinfo: addrinfo) {
        self.family = addrinfo.ai_family
        self.socktype = addrinfo.ai_socktype
        self.protocol = addrinfo.ai_protocol

        if let cname = addrinfo.ai_canonname {
            self.canonicalName = String(cString: cname)
        } else {
            self.canonicalName = nil
        }

        guard let addr = addrinfo.ai_addr else { return nil }
        self.addressData = Data(bytes: addr, count: Int(addrinfo.ai_addrlen))
    }

    /// Returns the address as a string (e.g., "192.168.1.1" or "::1").
    public var addressString: String? {
        addressData.withUnsafeBytes { buffer -> String? in
            guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                return nil
            }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let err = getnameinfo(
                addr,
                socklen_t(addressData.count),
                &host,
                host.count,
                nil,
                0,
                NI_NUMERICHOST
            )

            guard err == 0 else { return nil }
            return String(cString: host)
        }
    }
}

/// Host entry from legacy DNS lookup.
public struct HostEntry: Sendable {
    /// The official hostname.
    public let name: String
    /// Alias names for the host.
    public let aliases: [String]
    /// The address type (AF_INET or AF_INET6).
    public let addressType: Int32
    /// The length of each address.
    public let addressLength: Int32
    /// The addresses as raw data.
    public let addresses: [Data]

    init(hostent: hostent) {
        self.name = String(cString: hostent.h_name)
        self.addressType = hostent.h_addrtype
        self.addressLength = hostent.h_length

        var aliases: [String] = []
        if var ptr = hostent.h_aliases {
            while let alias = ptr.pointee {
                aliases.append(String(cString: alias))
                ptr += 1
            }
        }
        self.aliases = aliases

        var addrs: [Data] = []
        if var ptr = hostent.h_addr_list {
            while let addr = ptr.pointee {
                addrs.append(Data(bytes: addr, count: Int(hostent.h_length)))
                ptr += 1
            }
        }
        self.addresses = addrs
    }
}
