/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// Errors that can occur when using Casper services.
public enum CasperError: Error, Equatable {
    /// Failed to initialize the main Casper channel.
    case initFailed
    /// Failed to open a Casper service.
    case serviceOpenFailed(service: String)
    /// Failed to clone a channel.
    case cloneFailed
    /// Failed to set limits on a channel.
    case limitSetFailed(errno: Int32)
    /// A service operation failed.
    case operationFailed(errno: Int32)
    /// Invalid argument provided.
    case invalidArgument(String)
}

/// A communication channel to Casper or a Casper service.
///
/// `CasperChannel` provides access to Casper services from within a Capsicum
/// capability-mode sandbox. Services run in separate sandboxed processes and
/// handle operations that the sandboxed process cannot perform directly.
///
/// ## Usage
///
/// ```swift
/// // Initialize the main Casper channel (before entering capability mode)
/// let casper = try CasperChannel.create()
///
/// // Open specific services
/// let dns = try casper.openService(.dns)
/// let sysctl = try casper.openService(.sysctl)
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Use services within the sandbox
/// let addresses = try dns.getaddrinfo(hostname: "example.com")
/// ```
///
/// - Important: `CasperChannel.create()` must be called from a single-threaded
///   context before entering capability mode.
public struct CasperChannel: ~Copyable, Sendable {
    /// The underlying C channel pointer.
    private nonisolated(unsafe) let channel: UnsafeMutableRawPointer

    /// Creates a channel from a raw C pointer.
    ///
    /// The channel takes ownership of the pointer and will close it when
    /// the channel is deinitialized.
    private init(_ ptr: UnsafeMutableRawPointer) {
        self.channel = ptr
    }

    /// Creates the main Casper channel.
    ///
    /// This channel is used to open specific services. It must be created
    /// before entering capability mode, and from a single-threaded context.
    ///
    /// - Returns: The main Casper channel.
    /// - Throws: `CasperError.initFailed` if initialization fails.
    public static func create() throws -> CasperChannel {
        guard let ptr = ccasper_init() else {
            throw CasperError.initFailed
        }
        return CasperChannel(ptr)
    }

    /// Opens a named Casper service.
    ///
    /// - Parameter service: The service to open.
    /// - Returns: A channel to the service.
    /// - Throws: `CasperError.serviceOpenFailed` if the service cannot be opened.
    public func openService(_ service: CasperService) -> Result<CasperChannel, CasperError> {
        guard let ptr = ccasper_service_open(channel, service.rawValue) else {
            return .failure(.serviceOpenFailed(service: service.rawValue))
        }
        return .success(CasperChannel(ptr))
    }

    /// Opens a named Casper service (throwing version).
    ///
    /// - Parameter service: The service to open.
    /// - Returns: A channel to the service.
    /// - Throws: `CasperError.serviceOpenFailed` if the service cannot be opened.
    public func open(_ service: CasperService) throws -> CasperChannel {
        guard let ptr = ccasper_service_open(channel, service.rawValue) else {
            throw CasperError.serviceOpenFailed(service: service.rawValue)
        }
        return CasperChannel(ptr)
    }

    /// Creates an independent copy of this channel.
    ///
    /// The cloned channel can be used concurrently with the original.
    ///
    /// - Returns: A new channel connected to the same service.
    /// - Throws: `CasperError.cloneFailed` if cloning fails.
    public func clone() throws -> CasperChannel {
        guard let ptr = ccasper_clone(channel) else {
            throw CasperError.cloneFailed
        }
        return CasperChannel(ptr)
    }

    /// Returns the underlying socket descriptor.
    ///
    /// This can be used with `kqueue`, `select`, or `poll` to wait for
    /// data from the service.
    public var socket: Int32 {
        ccasper_sock(channel)
    }

    /// Limits which services can be opened from this channel.
    ///
    /// This can only be called on the main Casper channel, not on service channels.
    ///
    /// - Parameter services: The services that can be opened.
    /// - Throws: `CasperError.limitSetFailed` if the limit cannot be set.
    public func limitServices(_ services: [CasperService]) throws {
        let names = services.map { $0.rawValue }
        try names.withUnsafeBufferPointer { buffer in
            var pointers = buffer.map { UnsafePointer(strdup($0)) }
            defer { pointers.forEach { free(UnsafeMutablePointer(mutating: $0)) } }

            try pointers.withUnsafeMutableBufferPointer { ptrBuffer in
                let result = ccasper_service_limit(
                    channel,
                    ptrBuffer.baseAddress,
                    ptrBuffer.count
                )
                if result != 0 {
                    throw CasperError.limitSetFailed(errno: errno)
                }
            }
        }
    }

    /// Provides access to the underlying C channel pointer.
    ///
    /// - Warning: Do not close or modify the channel through this pointer.
    internal func withUnsafeChannel<R>(
        _ body: (UnsafeMutableRawPointer) throws -> R
    ) rethrows -> R {
        try body(channel)
    }

    deinit {
        ccasper_close(channel)
    }
}

/// Available Casper services.
public struct CasperService: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// DNS resolution service.
    ///
    /// Provides `getaddrinfo`, `getnameinfo`, and legacy `gethostby*` functions.
    public static let dns = CasperService(rawValue: "system.dns")

    /// Sysctl access service.
    ///
    /// Provides `sysctl`, `sysctlbyname`, and `sysctlnametomib` functions.
    public static let sysctl = CasperService(rawValue: "system.sysctl")

    /// Password database service.
    ///
    /// Provides `getpwent`, `getpwnam`, `getpwuid`, and related functions.
    public static let pwd = CasperService(rawValue: "system.pwd")

    /// Group database service.
    ///
    /// Provides `getgrent`, `getgrnam`, `getgrgid`, and related functions.
    public static let grp = CasperService(rawValue: "system.grp")

    /// File arguments service.
    ///
    /// Provides access to files specified on the command line.
    public static let fileargs = CasperService(rawValue: "system.fileargs")

    /// Network operations service.
    ///
    /// Provides libc-compatible network API.
    public static let net = CasperService(rawValue: "system.net")

    /// Network database service.
    ///
    /// Provides libc-compatible network protocol API.
    public static let netdb = CasperService(rawValue: "system.netdb")

    /// Syslog service.
    ///
    /// Provides `openlog`, `closelog`, `syslog`, and `setlogmask` functions.
    public static let syslog = CasperService(rawValue: "system.syslog")
}
