/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation

// MARK: - Socket Domain (Protocol Family)

/// Socket domain (protocol family) for socket creation
public struct SocketDomain: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Host-internal protocols (Unix domain sockets)
    public static let local = SocketDomain(rawValue: PF_LOCAL)
    public static let unix = SocketDomain(rawValue: PF_UNIX)

    /// Internet Protocol version 4
    public static let inet = SocketDomain(rawValue: PF_INET)

    /// Internet Protocol version 6
    public static let inet6 = SocketDomain(rawValue: PF_INET6)

    #if os(FreeBSD)
    /// Firewall packet diversion/re-injection
    public static let divert = SocketDomain(rawValue: PF_DIVERT)

    /// Internal routing protocol
    public static let route = SocketDomain(rawValue: PF_ROUTE)

    /// Internal key-management function
    public static let key = SocketDomain(rawValue: PF_KEY)

    /// Netgraph sockets
    public static let netgraph = SocketDomain(rawValue: 32) // PF_NETGRAPH

    /// Netlink protocols
    public static let netlink = SocketDomain(rawValue: 38) // PF_NETLINK

    /// Bluetooth protocols
    public static let bluetooth = SocketDomain(rawValue: 36) // PF_BLUETOOTH
    #endif
}

// MARK: - Socket Type

/// Socket type for socket creation
public struct SocketType: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    // Base types (mutually exclusive, but we use OptionSet for flags)
    /// Sequenced, reliable, connection-based byte streams
    public static let stream = SocketType(rawValue: SOCK_STREAM)

    /// Connectionless, unreliable datagrams of fixed max length
    public static let datagram = SocketType(rawValue: SOCK_DGRAM)

    /// Raw-protocol interface (superuser only)
    public static let raw = SocketType(rawValue: SOCK_RAW)

    /// Sequenced, reliable, connection-based, datagrams with record boundaries
    public static let seqpacket = SocketType(rawValue: SOCK_SEQPACKET)

    // Flags (can be OR'd with base types)
    #if os(FreeBSD)
    /// Set close-on-exec on the descriptor
    public static let cloexec = SocketType(rawValue: 0x10000000) // SOCK_CLOEXEC

    /// Set non-blocking I/O mode on the descriptor
    public static let nonblock = SocketType(rawValue: 0x20000000) // SOCK_NONBLOCK

    /// Set close-on-fork on the descriptor
    public static let clofork = SocketType(rawValue: 0x40000000) // SOCK_CLOFORK
    #endif
}

// MARK: - Socket Protocol

/// Socket protocol for socket creation
public struct SocketProtocol: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Default protocol (usually 0)
    public static let `default` = SocketProtocol(rawValue: 0)

    /// Internet Control Message Protocol
    public static let icmp = SocketProtocol(rawValue: IPPROTO_ICMP)

    /// Transmission Control Protocol
    public static let tcp = SocketProtocol(rawValue: IPPROTO_TCP)

    /// User Datagram Protocol
    public static let udp = SocketProtocol(rawValue: IPPROTO_UDP)

    #if os(FreeBSD)
    /// Stream Control Transmission Protocol
    public static let sctp = SocketProtocol(rawValue: 132) // IPPROTO_SCTP
    #endif
}

// MARK: - Shutdown Options

/// Socket shutdown operations
public struct SocketShutdown: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Disallow further receives
    public static let read = SocketShutdown(rawValue: 0) // SHUT_RD

    /// Disallow further sends
    public static let write = SocketShutdown(rawValue: 1) // SHUT_WR

    /// Disallow further sends and receives
    public static let readWrite = SocketShutdown(rawValue: 2) // SHUT_RDWR
}

// MARK: - Socket Address Wrapper

/// Type-safe wrapper for socket addresses
public protocol SocketAddress {
    /// Returns a pointer to the underlying sockaddr structure
    /// The pointer is only valid for the duration of the closure
    func withSockAddr<R>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> R) rethrows -> R
}

/// IPv4 socket address
public struct IPv4SocketAddress: SocketAddress {
    private var storage: sockaddr_in

    public init(address: String, port: UInt16) throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian

        guard inet_pton(AF_INET, address, &addr.sin_addr) == 1 else {
            throw POSIXError(.EINVAL)
        }

        self.storage = addr
    }

    public init(port: UInt16, address: in_addr = in_addr(s_addr: INADDR_ANY.bigEndian)) {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = address
        self.storage = addr
    }

    public func withSockAddr<R>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> R) rethrows -> R {
        try withUnsafePointer(to: storage) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}

/// IPv6 socket address
public struct IPv6SocketAddress: SocketAddress {
    private var storage: sockaddr_in6

    public init(address: String, port: UInt16) throws {
        var addr = sockaddr_in6()
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian

        guard inet_pton(AF_INET6, address, &addr.sin6_addr) == 1 else {
            throw POSIXError(.EINVAL)
        }

        self.storage = addr
    }

    public init(port: UInt16, address: in6_addr = in6addr_any) {
        var addr = sockaddr_in6()
        addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian
        addr.sin6_addr = address
        self.storage = addr
    }

    public func withSockAddr<R>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> R) rethrows -> R {
        try withUnsafePointer(to: storage) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
    }
}

/// Unix domain socket address
public struct UnixSocketAddress: SocketAddress {
    private var storage: sockaddr_un

    public init(path: String) throws {
        var addr = sockaddr_un()
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy path into sun_path, leaving room for null terminator
        let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        guard path.utf8.count <= maxPathLen else {
            throw POSIXError(.ENAMETOOLONG)
        }

        withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
            _ = path.withCString { cstr in
                strlcpy(ptr.baseAddress?.assumingMemoryBound(to: CChar.self), cstr, ptr.count)
            }
        }

        self.storage = addr
    }

    public func withSockAddr<R>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> R) rethrows -> R {
        try withUnsafePointer(to: storage) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
