/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors
import Capabilities

// MARK: - BPCListener

/// The interface for a BPC connection listener.
///
/// A listener accepts incoming connections on a Unix-domain socket. Obtain a
/// concrete implementation via ``BSDListener/listen(on:)``, then call ``start()``
/// before iterating over ``connections()``.
///
/// ## Lifecycle
/// 1. Call ``start()`` to begin the accept loop.
/// 2. Iterate over ``connections()`` or call ``accept()`` directly.
/// 3. Call ``stop()`` to close the listening socket and finish the connection stream.
public protocol BPCListener: Actor {
    /// Starts the accept loop. Must be called before ``connections()``.
    func start()

    /// Stops the accept loop and closes the listening socket.
    func stop()

    /// Returns the stream of incoming connections.
    ///
    /// Can only be claimed by one task. The stream finishes when the listener
    /// is stopped or encounters a fatal socket error.
    ///
    /// - Throws: ``BPCError/notStarted`` if ``start()`` has not been called,
    ///           ``BPCError/listenerClosed`` if ``stop()`` has been called,
    ///           ``BPCError/streamAlreadyClaimed`` if already claimed by another task.
    func connections() throws -> AsyncThrowingStream<BSDEndpoint, Error>

    /// Accepts the next incoming connection. Suspends until a client connects.
    ///
    /// - Throws: ``BPCError/listenerClosed`` if the listener has been stopped.
    func accept() async throws -> BSDEndpoint
}

// MARK: - BSDListener

/// A ``BPCListener`` backed by a BSD Unix-domain SEQPACKET socket.
///
/// Uses SOCK_SEQPACKET for connection-oriented, message-boundary-preserving
/// communication. Obtain an instance via ``listen(on:)``. After calling
/// ``start()``, iterate over ``connections()`` to receive newly accepted
/// ``BSDEndpoint`` instances, or call ``accept()`` to handle one connection
/// at a time.
public actor BSDListener: BPCListener {
    private let socketHolder: SocketHolder
    private let ioQueue: DispatchQueue
    private var state: LifecycleState = .idle
    private var connectionStream: AsyncThrowingStream<BSDEndpoint, Error>?
    private var connectionContinuation: AsyncThrowingStream<BSDEndpoint, Error>.Continuation?
    private var acceptLoopTask: Task<Void, Never>?

    // MARK: - Listen

    /// Begins listening on a Unix-domain socket at the given path.
    ///
    /// - Parameters:
    ///   - path: The filesystem path at which to bind the socket.
    ///   - ioQueue: Optional custom DispatchQueue for I/O operations. If `nil`, a default queue is created.
    /// - Returns: A new, unstarted ``BSDListener``. Call ``start()`` before use.
    /// - Throws: A system error if the socket cannot be created or bound.
    public static func listen(on path: String, ioQueue: DispatchQueue? = nil) throws -> BSDListener {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.seqpacket, .cloexec],
            protocol: .default
        )
        let address = try UnixSocketAddress(path: path)
        try socket.bind(address: address)
        try socket.listen(backlog: 128)
        return BSDListener(socket: socket, ioQueue: ioQueue)
    }

    private init(socket: consuming SocketCapability, ioQueue: DispatchQueue? = nil) {
        self.socketHolder = SocketHolder(socket: socket)
        self.ioQueue = ioQueue ?? DispatchQueue(label: "com.bpc.listener.io", qos: .userInitiated)
    }

    // MARK: Lifecycle

    public func start() {
        state = .running
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: BSDEndpoint.self)
        connectionStream = stream
        connectionContinuation = continuation

        acceptLoopTask = Task {
            do {
                while state == .running {
                    let endpoint = try await accept()
                    connectionContinuation?.yield(endpoint)
                }
                connectionContinuation?.finish()
            } catch {
                connectionContinuation?.finish(throwing: error)
            }
        }
    }

    public func stop() {
        state = .stopped
        acceptLoopTask?.cancel()
        acceptLoopTask = nil
        socketHolder.close()
        connectionContinuation?.finish()
        connectionContinuation = nil
    }

    // MARK: - Public API

    /// Returns the stream of incoming connections.
    ///
    /// Can only be claimed by one task. Throws `.notStarted` if ``start()`` has not been
    /// called, `.listenerClosed` if ``stop()`` has been called, or `.streamAlreadyClaimed`
    /// if already claimed.
    public func connections() throws -> AsyncThrowingStream<BSDEndpoint, Error> {
        switch state {
        case .idle:    throw BPCError.notStarted
        case .stopped: throw BPCError.listenerClosed
        case .running: break
        }
        guard let stream = connectionStream else {
            throw BPCError.streamAlreadyClaimed
        }
        connectionStream = nil
        return stream
    }

    /// Accepts the next incoming connection. Suspends until a client connects.
    ///
    /// - Throws: ``BPCError/listenerClosed`` if the listener has been stopped.
    public func accept() async throws -> BSDEndpoint {
        guard state == .running else { throw BPCError.listenerClosed }

        return try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    guard let clientSocket = try self.socketHolder.withSocket({ socket in
                        try socket.accept()
                    }) else {
                        continuation.resume(throwing: BPCError.listenerClosed)
                        return
                    }
                    continuation.resume(returning: BSDEndpoint(socket: clientSocket))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
