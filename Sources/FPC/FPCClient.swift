/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors
import Capabilities

// MARK: - FPCClient

/// An FPC client that connects to SEQPACKET servers.
///
/// This client establishes a connection-oriented, message-boundary-preserving
/// Unix-domain socket connection and returns an ``FPCEndpoint`` for communication.
///
/// ## Example
/// ```swift
/// let endpoint = try FPCClient.connect(path: "/tmp/fpc.sock")
/// await endpoint.start()
/// try await endpoint.send(message)
/// ```
public struct FPCClient {

    /// Connects to a SEQPACKET FPC server.
    ///
    /// Creates a Unix-domain SEQPACKET socket, connects to the server at the given
    /// path, and returns an ``FPCEndpoint`` wrapping the connected socket.
    ///
    /// - Parameters:
    ///   - path: The filesystem path of the server's socket
    ///   - ioQueue: Optional custom DispatchQueue for I/O operations. If `nil`, a default queue is created.
    /// - Returns: A new, unstarted ``FPCEndpoint``. Call ``start()`` before use.
    /// - Throws: A system error if the socket cannot be created or the connection is refused
    public static func connect(path: String, ioQueue: DispatchQueue? = nil) throws -> FPCEndpoint {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.seqpacket, .cloexec],
            protocol: .default
        )
        let address = try UnixSocketAddress(path: path)
        try socket.connect(address: address)
        return FPCEndpoint(socket: socket, ioQueue: ioQueue)
    }
}
