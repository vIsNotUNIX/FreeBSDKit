/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Descriptors
import Capabilities

// MARK: - Message

public struct Message: Sendable {
    public var id: MessageID
    public var correlationID: UInt32  // 0 = unsolicited, >0 = part of a request/reply flow
    public var payload: Data
    public var descriptors: [OpaqueDescriptorRef]

    public init(
        id: MessageID,
        correlationID: UInt32 = 0,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) {
        self.id = id
        self.correlationID = correlationID
        self.payload = payload
        self.descriptors = descriptors
    }

    /// A message that expects a reply. The endpoint assigns correlationID on send.
    public static func request(
        _ id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(id: id, correlationID: 0, payload: payload, descriptors: descriptors)
    }

    /// A one-way message. No reply expected.
    public static func notification(
        _ id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(id: id, correlationID: 0, payload: payload, descriptors: descriptors)
    }
}

public enum MessageID: UInt32, Sendable {
    case ping           = 1
    case pong           = 2
    case lookup         = 3
    case lookupReply    = 4
    case subscribe      = 5
    case subscribeAck   = 6
    case event          = 7    // unsolicited server push
    case error          = 255
}

// MARK: - Errors

public enum BPCError: Error, Sendable {
    case disconnected
    case listenerClosed
    case invalidMessageFormat
    case unsupportedVersion(UInt8)
    case unexpectedMessage(MessageID)
    case timeout
}

// MARK: - SocketHolder

/// Wraps ~Copyable SocketCapability for use in reference-typed containers.
private final class SocketHolder: @unchecked Sendable {
    private var socket: SocketCapability?
    private let lock = NSLock()

    init(socket: consuming SocketCapability) {
        self.socket = consume socket
    }

    deinit {
        close()
    }

    func withSocket<R>(_ body: (borrowing SocketCapability) throws -> R) rethrows -> R? where R: ~Copyable {
        lock.lock()
        defer { lock.unlock() }
        guard socket != nil else { return nil }
        return try body(socket!)
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard socket != nil else { return }
        socket!.unsafe { fd in _ = Glibc.close(fd) }
        self.socket = nil
    }
}

// MARK: - Endpoint

public actor BSDEndpoint {

    // MARK: Private State

    private let socketHolder: SocketHolder
    private let ioQueue = DispatchQueue(label: "com.bpc.endpoint.io", qos: .userInitiated)

    private var nextCorrelationID: UInt32 = 1
    private var pendingReplies: [UInt32: CheckedContinuation<Message, Error>] = [:]
    private var incomingContinuation: AsyncStream<Message>.Continuation?
    private var receiveLoopTask: Task<Void, Never>?

    // MARK: Init

    public init(socket: consuming SocketCapability) {
        self.socketHolder = SocketHolder(socket: socket)
    }

    public func start() {
        receiveLoopTask = Task {
            await receiveLoop()
        }
    }

    public func stop() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        socketHolder.close()
        teardown(throwing: BPCError.disconnected)
    }

    // MARK: - Public API

    /// Fire and forget. Awaiting means the bytes are on the wire, nothing more.
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

    /// Send a request and suspend until the matching reply arrives.
    public func request(_ message: Message) async throws -> Message {
        var outgoing = message
        outgoing.correlationID = nextCorrelationID
        nextCorrelationID &+= 1

        try await send(outgoing)

        return try await withCheckedThrowingContinuation { continuation in
            pendingReplies[outgoing.correlationID] = continuation
        }
    }

    /// Continuous stream of unsolicited messages — server pushes, events, etc.
    /// Only one consumer at a time; a second call replaces the first continuation.
    public var messages: AsyncStream<Message> {
        AsyncStream { continuation in
            self.incomingContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.clearIncomingContinuation() }
            }
        }
    }

    // MARK: - Connect

    public static func connect(path: String) throws -> BSDEndpoint {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )
        let address = try UnixSocketAddress(path: path)
        try socket.connect(address: address)
        return BSDEndpoint(socket: socket)
    }

    // MARK: - Private

    private func clearIncomingContinuation() {
        incomingContinuation = nil
    }

    /// Every incoming message routes through here exactly once.
    private func dispatch(_ message: Message) {
        if message.correlationID != 0,
           let continuation = pendingReplies.removeValue(forKey: message.correlationID) {
            continuation.resume(returning: message)
        } else {
            // If ! a named response yield the message. 
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

    /// The one place blocking I/O happens — pushed off the cooperative pool.
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

    /// Called when the socket dies — fail all waiting callers.
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
    // All wire format I/O is called on ioQueue, never on the actor.
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

        var messageID = message.id.rawValue.bigEndian
        header.replaceSubrange(0..<4, with: Data(bytes: &messageID, count: 4))

        var correlationID = message.correlationID.bigEndian
        header.replaceSubrange(4..<8, with: Data(bytes: &correlationID, count: 4))

        var payloadLength = UInt32(message.payload.count).bigEndian
        header.replaceSubrange(8..<12, with: Data(bytes: &payloadLength, count: 4))

        header[12] = UInt8(min(message.descriptors.count, 255))
        header[13] = 0  // version

        var wireData = header
        wireData.append(message.payload)
        wireData.append(Data(count: 256))  // trailer

        try socketHolder.withSocket { socket in
            try socket.sendDescriptors(message.descriptors, payload: wireData)
        } ?? { throw BPCError.disconnected }()
    }

    nonisolated private func socketReceive() throws -> Message {
        // Max buffer: 256-byte header + 1MB payload + 256-byte trailer
        let maxBufferSize = 256 + (1024 * 1024) + 256

        guard let (wireData, descriptors) = try socketHolder.withSocket({ socket in
            try socket.recvDescriptors(maxDescriptors: 255, bufferSize: maxBufferSize)
        }) else {
            throw BPCError.disconnected
        }

        guard wireData.count >= 256 else {
            throw BPCError.invalidMessageFormat
        }

        let messageIDRaw = Data(wireData[0..<4]).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard let messageID = MessageID(rawValue: messageIDRaw) else {
            throw BPCError.invalidMessageFormat
        }

        let correlationID = Data(wireData[4..<8]).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        let payloadLength = Data(wireData[8..<12]).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

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

// MARK: - Listener

public actor BSDListener {

    private let socketHolder: SocketHolder
    private let ioQueue = DispatchQueue(label: "com.bpc.listener.io", qos: .userInitiated)
    private var isActive: Bool = true

    public static func unix(path: String) throws -> BSDListener {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )
        let address = try UnixSocketAddress(path: path)
        try socket.bind(address: address)
        try socket.listen(backlog: 128)
        return BSDListener(socket: socket)
    }

    private init(socket: consuming SocketCapability) {
        self.socketHolder = SocketHolder(socket: socket)
    }

    /// Accept the next incoming connection. Suspends until a client connects.
    public func accept() async throws -> BSDEndpoint {
        guard isActive else { throw BPCError.listenerClosed }

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

    public func stop() {
        isActive = false
        socketHolder.close()
    }
}
