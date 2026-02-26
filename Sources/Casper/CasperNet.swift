/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Foundation
import Glibc

/// Network operations service for Capsicum sandboxes.
///
/// `CasperNet` wraps a Casper network service channel and provides type-safe
/// Swift interfaces to network operations that work within capability mode.
/// This service provides more comprehensive network access than `CasperDNS`,
/// including the ability to bind and connect sockets.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let net = try CasperNet(casper: casper)
///
/// // Limit to specific operations
/// try net.limit(mode: [.connect, .nameToAddress])
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Use network operations from the sandbox
/// let addresses = try net.getaddrinfo(hostname: "example.com", port: "443")
/// try net.connect(socket: sock, address: addr)
/// ```
public struct CasperNet: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a network service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the network service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.net)
    }

    /// Creates a network service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the network service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Network operation modes.
    public struct Mode: OptionSet, Sendable {
        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// Allow reverse DNS lookups (address to name).
        public static let addressToName = Mode(rawValue: CCASPER_CAPNET_ADDR2NAME)
        /// Allow forward DNS lookups (name to address).
        public static let nameToAddress = Mode(rawValue: CCASPER_CAPNET_NAME2ADDR)
        /// Allow deprecated reverse DNS functions.
        public static let deprecatedAddressToName = Mode(rawValue: CCASPER_CAPNET_DEPRECATED_ADDR2NAME)
        /// Allow deprecated forward DNS functions.
        public static let deprecatedNameToAddress = Mode(rawValue: CCASPER_CAPNET_DEPRECATED_NAME2ADDR)
        /// Allow connect operations.
        public static let connect = Mode(rawValue: CCASPER_CAPNET_CONNECT)
        /// Allow bind operations.
        public static let bind = Mode(rawValue: CCASPER_CAPNET_BIND)
        /// Allow DNS lookups for connect operations.
        public static let connectDNS = Mode(rawValue: CCASPER_CAPNET_CONNECTDNS)

        /// All DNS operations.
        public static let allDNS: Mode = [.addressToName, .nameToAddress]
        /// All socket operations.
        public static let allSocket: Mode = [.connect, .bind]
        /// All operations.
        public static let all: Mode = [.addressToName, .nameToAddress, .connect, .bind, .connectDNS]
    }

    /// A builder for configuring network service limits.
    public class LimitBuilder: @unchecked Sendable {
        private var limit: UnsafeMutableRawPointer?

        init(limit: UnsafeMutableRawPointer?) {
            self.limit = limit
        }

        /// Limits reverse DNS lookups to specific address families.
        ///
        /// - Parameter addressToNameFamilies: The allowed address families (e.g., AF_INET, AF_INET6).
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(addressToNameFamilies families: [Int32]) -> LimitBuilder {
            guard let lim = limit else { return self }
            var fams = families
            limit = fams.withUnsafeMutableBufferPointer { buffer in
                ccasper_net_limit_addr2name_family(lim, buffer.baseAddress, buffer.count)
            }
            return self
        }

        /// Limits reverse DNS lookups to a specific address.
        ///
        /// - Parameter addressToName: The allowed socket address.
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(addressToName address: Data) -> LimitBuilder {
            guard var lim = limit else { return self }
            address.withUnsafeBytes { buffer in
                guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                    return
                }
                lim = ccasper_net_limit_addr2name(lim, addr, socklen_t(address.count))
            }
            limit = lim
            return self
        }

        /// Limits forward DNS lookups to specific address families.
        ///
        /// - Parameter nameToAddressFamilies: The allowed address families.
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(nameToAddressFamilies families: [Int32]) -> LimitBuilder {
            guard let lim = limit else { return self }
            var fams = families
            limit = fams.withUnsafeMutableBufferPointer { buffer in
                ccasper_net_limit_name2addr_family(lim, buffer.baseAddress, buffer.count)
            }
            return self
        }

        /// Limits forward DNS lookups to specific hostnames.
        ///
        /// - Parameters:
        ///   - nameToAddress: The allowed hostname.
        ///   - service: The allowed service name (optional).
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(nameToAddress name: String, service: String? = nil) -> LimitBuilder {
            guard var lim = limit else { return self }
            name.withCString { namePtr in
                if let service = service {
                    service.withCString { servPtr in
                        lim = ccasper_net_limit_name2addr(lim, namePtr, servPtr)
                    }
                } else {
                    lim = ccasper_net_limit_name2addr(lim, namePtr, nil)
                }
            }
            limit = lim
            return self
        }

        /// Limits connect operations to a specific address.
        ///
        /// - Parameter connect: The allowed socket address.
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(connect address: Data) -> LimitBuilder {
            guard var lim = limit else { return self }
            address.withUnsafeBytes { buffer in
                guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                    return
                }
                lim = ccasper_net_limit_connect(lim, addr, socklen_t(address.count))
            }
            limit = lim
            return self
        }

        /// Limits bind operations to a specific address.
        ///
        /// - Parameter bind: The allowed socket address.
        /// - Returns: Self for chaining.
        @discardableResult
        public func limit(bind address: Data) -> LimitBuilder {
            guard var lim = limit else { return self }
            address.withUnsafeBytes { buffer in
                guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                    return
                }
                lim = ccasper_net_limit_bind(lim, addr, socklen_t(address.count))
            }
            limit = lim
            return self
        }

        /// Applies the configured limits.
        ///
        /// - Throws: `CasperError.limitSetFailed` if the limits cannot be applied.
        public func apply() throws {
            guard let lim = limit else {
                throw CasperError.limitSetFailed(errno: EINVAL)
            }
            let result = ccasper_net_limit(lim)
            limit = nil // Ownership transferred
            if result != 0 {
                throw CasperError.limitSetFailed(errno: errno)
            }
        }

        deinit {
            if let lim = limit {
                ccasper_net_free(lim)
            }
        }
    }

    /// Creates a limit builder for configuring service limits.
    ///
    /// - Parameter mode: The operation modes to enable.
    /// - Returns: A builder for configuring limits.
    public func limitBuilder(mode: Mode) -> LimitBuilder {
        let limitPtr: UnsafeMutableRawPointer? = channel.withUnsafeChannel { chan in
            ccasper_net_limit_init(chan, mode.rawValue)
        }
        return LimitBuilder(limit: limitPtr)
    }

    /// Applies simple mode limits to the service.
    ///
    /// - Parameter mode: The operation modes to enable.
    /// - Throws: `CasperError.limitSetFailed` if the limits cannot be applied.
    public func limit(mode: Mode) throws {
        try limitBuilder(mode: mode).apply()
    }

    /// Binds a socket to an address.
    ///
    /// - Parameters:
    ///   - socket: The socket file descriptor.
    ///   - address: The address to bind to.
    /// - Throws: `CasperError.operationFailed` if the bind fails.
    public func bind(socket: Int32, address: Data) throws {
        let result = address.withUnsafeBytes { buffer -> Int32 in
            guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                return -1
            }
            return channel.withUnsafeChannel { chan in
                ccasper_net_bind(chan, socket, addr, socklen_t(address.count))
            }
        }
        if result != 0 {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Binds a socket to a sockaddr_in.
    ///
    /// - Parameters:
    ///   - socket: The socket file descriptor.
    ///   - address: The IPv4 address to bind to.
    /// - Throws: `CasperError.operationFailed` if the bind fails.
    public func bind(socket: Int32, address: inout sockaddr_in) throws {
        let result = withUnsafePointer(to: &address) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                channel.withUnsafeChannel { chan in
                    ccasper_net_bind(chan, socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        if result != 0 {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Connects a socket to an address.
    ///
    /// - Parameters:
    ///   - socket: The socket file descriptor.
    ///   - address: The address to connect to.
    /// - Throws: `CasperError.operationFailed` if the connect fails.
    public func connect(socket: Int32, address: Data) throws {
        let result = address.withUnsafeBytes { buffer -> Int32 in
            guard let addr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                return -1
            }
            return channel.withUnsafeChannel { chan in
                ccasper_net_connect(chan, socket, addr, socklen_t(address.count))
            }
        }
        if result != 0 {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Connects a socket to a sockaddr_in.
    ///
    /// - Parameters:
    ///   - socket: The socket file descriptor.
    ///   - address: The IPv4 address to connect to.
    /// - Throws: `CasperError.operationFailed` if the connect fails.
    public func connect(socket: Int32, address: inout sockaddr_in) throws {
        let result = withUnsafePointer(to: &address) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                channel.withUnsafeChannel { chan in
                    ccasper_net_connect(chan, socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        if result != 0 {
            throw CasperError.operationFailed(errno: errno)
        }
    }

    /// Resolves a hostname to addresses.
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
                        ccasper_net_getaddrinfo(chan, hostnamePtr, portPtr, &hints, &result)
                    }
                }
            } else {
                return channel.withUnsafeChannel { chan in
                    ccasper_net_getaddrinfo(chan, hostnamePtr, nil, &hints, &result)
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
    ///   - length: The length of the address.
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
            ccasper_net_getnameinfo(
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

        return (
            host.withUnsafeBytes { ptr in
                let utf8 = ptr.bindMemory(to: UInt8.self)
                let length = utf8.firstIndex(of: 0) ?? utf8.count
                return String(decoding: utf8.prefix(length), as: UTF8.self)
            },
            serv.withUnsafeBytes { ptr in
                let utf8 = ptr.bindMemory(to: UInt8.self)
                let length = utf8.firstIndex(of: 0) ?? utf8.count
                return String(decoding: utf8.prefix(length), as: UTF8.self)
            }
        )
    }

    /// Resolves a hostname using the legacy `gethostbyname` interface.
    ///
    /// - Parameter name: The hostname to resolve.
    /// - Returns: Host information, or `nil` if not found.
    /// - Note: This function is deprecated. Use `getaddrinfo` instead.
    @available(*, deprecated, message: "Use getaddrinfo instead")
    public func gethostbyname(_ name: String) -> HostEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_net_gethostbyname(chan, namePtr)
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
    /// - Note: This function is deprecated. Use `getaddrinfo` instead.
    @available(*, deprecated, message: "Use getaddrinfo instead")
    public func gethostbyname2(_ name: String, family: Int32) -> HostEntry? {
        let result = name.withCString { namePtr in
            channel.withUnsafeChannel { chan in
                ccasper_net_gethostbyname2(chan, namePtr, family)
            }
        }
        guard let hostent = result else { return nil }
        return HostEntry(hostent: hostent.pointee)
    }
}
