/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FreeBSDKit
import Descriptors
import Capabilities

// MARK: - BPCEndpoint

/// The interface for a BPC connection endpoint.
///
/// An endpoint represents one side of an established socket connection. Obtain a
/// concrete implementation via ``BSDEndpoint/connect(path:)``, then call ``start()``
/// before exchanging messages.
///
/// ## Lifecycle
/// 1. Call ``start()`` to begin the receive loop.
/// 2. Use ``send(_:)``, ``request(_:)``, and ``messages()`` to exchange messages.
/// 3. Call ``stop()`` to tear down the connection and fail any pending callers.
public protocol BPCEndpoint: Actor {
    /// Starts the receive loop. Must be called before ``messages()`` or sending.
    func start()

    /// Stops the receive loop, closes the socket, and fails any suspended callers.
    func stop()

    /// Sends a fire-and-forget message. Suspends until the bytes are on the wire.
    func send(_ message: Message) async throws

    /// Sends a message and suspends until the matching reply arrives.
    ///
    /// The endpoint assigns a correlation ID to `message` before sending. The
    /// reply is matched by that same ID and delivered to the caller.
    func request(_ message: Message) async throws -> Message

    /// Returns the stream of unsolicited inbound messages.
    ///
    /// Can only be claimed by one task. The stream finishes when the connection
    /// is lost or ``stop()`` is called.
    ///
    /// - Throws: ``BPCError/notStarted`` if ``start()`` has not been called,
    ///           ``BPCError/disconnected`` if ``stop()`` has been called,
    ///           ``BPCError/streamAlreadyClaimed`` if already claimed by another task.
    func messages() throws -> AsyncStream<Message>
}

// MARK: - BSDEndpoint

/// A ``BPCEndpoint`` backed by a BSD Unix-domain socket.
///
/// Obtain an instance via ``connect(path:)``. After calling ``start()``, use
/// ``send(_:)`` and ``request(_:)`` to write to the wire, and ``messages()`` to
/// consume unsolicited inbound messages.
public actor BSDEndpoint: BPCEndpoint {
    private let socketHolder: SocketHolder
    private let ioQueue: DispatchQueue
    private var nextCorrelationID: UInt32 = 1
    private var pendingReplies: [UInt32: CheckedContinuation<Message, Error>] = [:]
    private var incomingContinuation: AsyncStream<Message>.Continuation?
    private var messageStream: AsyncStream<Message>?
    private var receiveLoopTask: Task<Void, Never>?
    private var state: LifecycleState = .idle

    // MARK: Init

    public init(socket: consuming SocketCapability, ioQueue: DispatchQueue? = nil) {
        self.socketHolder = SocketHolder(socket: socket)
        self.ioQueue = ioQueue ?? DispatchQueue(label: "com.bpc.endpoint.io", qos: .userInitiated)
    }

    // MARK: Lifecycle

    public func start() {
        state = .running
        let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
        messageStream = stream
        incomingContinuation = continuation

        receiveLoopTask = Task {
            await receiveLoop()
        }
    }

    public func stop() {
        state = .stopped
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        socketHolder.close()
        teardown(throwing: BPCError.disconnected)
    }

    // MARK: - Public API

    /// Sends a fire-and-forget message. Suspends until the bytes are on the wire.
    public func send(_ message: Message) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ioQueue.async {
                do {
                    try self.socketSend(message)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Sends a message and suspends until the matching reply arrives.
    ///
    /// A correlation ID is assigned automatically; the `correlationID` field of
    /// `message` is overwritten before sending.
    public func request(_ message: Message) async throws -> Message {
        var outgoing = message
        outgoing.correlationID = nextCorrelationID
        nextCorrelationID &+= 1

        try await send(outgoing)

        return try await withCheckedThrowingContinuation { continuation in
            pendingReplies[outgoing.correlationID] = continuation
        }
    }

    /// Returns the stream of unsolicited inbound messages.
    ///
    /// Can only be claimed by one task. Throws `.notStarted` if ``start()`` has
    /// not been called, `.disconnected` if ``stop()`` has been called, or
    /// `.streamAlreadyClaimed` if already claimed.
    public func messages() throws -> AsyncStream<Message> {
        switch state {
        case .idle:    throw BPCError.notStarted
        case .stopped: throw BPCError.disconnected
        case .running: break
        }
        guard let stream = messageStream else {
            throw BPCError.streamAlreadyClaimed
        }
        messageStream = nil
        return stream
    }

    // MARK: - Connect

    /// Connects to a BPC server at the given Unix-domain socket path.
    ///
    /// - Parameters:
    ///   - path: The filesystem path of the server's socket.
    ///   - ioQueue: Optional custom DispatchQueue for I/O operations. If `nil`, a default queue is created.
    /// - Returns: A new, unstarted ``BSDEndpoint``. Call ``start()`` before use.
    /// - Throws: A system error if the socket cannot be created or the connection is refused.
    public static func connect(path: String, ioQueue: DispatchQueue? = nil) throws -> BSDEndpoint {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )
        let address = try UnixSocketAddress(path: path)
        try socket.connect(address: address)
        return BSDEndpoint(socket: socket, ioQueue: ioQueue)
    }

    /// Creates a pair of connected ``BSDEndpoint`` instances using `socketpair(2)`.
    ///
    /// The returned endpoints are bidirectionally connected and ready for local IPC.
    /// Both are unstarted; call ``start()`` on each before exchanging messages.
    ///
    /// Each endpoint gets its own independent I/O queue to avoid serialization bottlenecks
    /// and potential deadlocks when the endpoints communicate with each other.
    ///
    /// - Returns: A tuple of two connected endpoints, each with its own I/O queue.
    /// - Throws: A system error if the socketpair cannot be created.
    public static func pair() throws -> (BSDEndpoint, BSDEndpoint) {
        let socketPair = try SocketCapability.socketPair(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )
        return (BSDEndpoint(socket: socketPair.first),
                BSDEndpoint(socket: socketPair.second))
    }

    // MARK: - Private

    /// Routes an incoming message to a waiting `request()` caller or the unsolicited stream.
    private func dispatch(_ message: Message) {
        if message.correlationID != 0,
           let continuation = pendingReplies.removeValue(forKey: message.correlationID) {
            continuation.resume(returning: message)
        } else {
            incomingContinuation?.yield(message)
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let message = try await receiveFromSocket()
                dispatch(message)
            } catch {
                teardown(throwing: error)
                break
            }
        }
    }

    /// Suspends until one complete message arrives on the socket.
    /// Blocking I/O is pushed off the cooperative thread pool onto `ioQueue`.
    private func receiveFromSocket() async throws -> Message {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    let message = try self.socketReceive()
                    continuation.resume(returning: message)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fails all suspended callers and closes the unsolicited message stream.
    private func teardown(throwing error: Error) {
        for (_, continuation) in pendingReplies {
            continuation.resume(throwing: error)
        }
        pendingReplies.removeAll()
        incomingContinuation?.finish()
        incomingContinuation = nil
    }

    // MARK: - Wire Format
    //
    // All wire format I/O runs on ioQueue, never on the actor executor.
    //
    // Layout: 256-byte fixed header | variable payload | 256-byte fixed trailer
    //
    // Header offsets:
    //   [messageID: UInt32]         4 bytes  offset  0
    //   [correlationID: UInt32]     4 bytes  offset  4
    //   [payloadLength: UInt32]     4 bytes  offset  8
    //   [descriptorCount: UInt8]    1 byte   offset 12
    //   [version: UInt8]            1 byte   offset 13
    //   [reserved: UInt8[242]]    242 bytes  offset 14
    //
    // Trailer: 256 bytes, reserved for future use (zeros on send).

    nonisolated private func socketSend(_ message: Message) throws {
        var header = Data(count: 256)

        var messageID = message.id.rawValue
        header.replaceSubrange(0..<4, with: Data(bytes: &messageID, count: 4))

        var correlationID = message.correlationID
        header.replaceSubrange(4..<8, with: Data(bytes: &correlationID, count: 4))

        var payloadLength = UInt32(message.payload.count)
        header.replaceSubrange(8..<12, with: Data(bytes: &payloadLength, count: 4))

        header[12] = UInt8(min(message.descriptors.count, 255))
        header[13] = 0  // version

        var wireData = header
        wireData.append(message.payload)
        wireData.append(Data(count: 256))  // trailer

        try socketHolder.withSocketOrThrow { socket in
            try socket.sendDescriptors(message.descriptors, payload: wireData)
        }
    }

    nonisolated private func socketReceive() throws -> Message {
        // Max buffer: 256-byte header + 1 MB payload + 256-byte trailer
        let maxBufferSize = 256 + (1024 * 1024) + 256

        let (wireData, descriptors) = try socketHolder.withSocketOrThrow { socket in
            try socket.recvDescriptors(maxDescriptors: 255, bufferSize: maxBufferSize)
        }

        guard wireData.count >= 256 else {
            throw BPCError.invalidMessageFormat
        }

        let messageIDRaw = Data(wireData[0..<4]).withUnsafeBytes { $0.load(as: UInt32.self) }
        guard let messageID = MessageID(rawValue: messageIDRaw) else {
            throw BPCError.invalidMessageFormat
        }

        let correlationID = Data(wireData[4..<8]).withUnsafeBytes { $0.load(as: UInt32.self) }
        let payloadLength = Data(wireData[8..<12]).withUnsafeBytes { $0.load(as: UInt32.self) }
        let descriptorCount = wireData[12]

        let version = wireData[13]
        guard version == 0 else {
            throw BPCError.unsupportedVersion(version)
        }

        let expectedTotal = 256 + Int(payloadLength) + 256
        guard wireData.count == expectedTotal else {
            throw BPCError.invalidMessageFormat
        }

        guard descriptors.count == Int(descriptorCount) else {
            throw BPCError.invalidMessageFormat
        }

        let payload = Data(wireData[256..<(256 + Int(payloadLength))])

        return Message(
            id: messageID,
            correlationID: correlationID,
            payload: payload,
            descriptors: descriptors
        )
    }
}
