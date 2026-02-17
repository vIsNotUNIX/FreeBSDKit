/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors
import Capabilities

// MARK: - Message Protocol

/// A message that can be sent over an IPC connection
public protocol Message: Sendable, Codable {
    /// The message type identifier
    static var messageType: String { get }
}

/// Envelope containing a message and optional descriptors
public struct MessageEnvelope: Sendable {
    /// The encoded message payload
    public let payload: Data

    /// The message type identifier
    public let messageType: String

    /// Optional file descriptors being passed with this message
    public let descriptors: [OpaqueDescriptorRef]

    public init(payload: Data, messageType: String, descriptors: [OpaqueDescriptorRef] = []) {
        self.payload = payload
        self.messageType = messageType
        self.descriptors = descriptors
    }

    /// Create an envelope from a message
    public init<M: Message>(message: M, descriptors: [OpaqueDescriptorRef] = []) throws {
        let encoder = JSONEncoder()
        self.payload = try encoder.encode(message)
        self.messageType = M.messageType
        self.descriptors = descriptors
    }

    /// Decode the envelope into a specific message type
    public func decode<M: Message>(as type: M.Type) throws -> M {
        guard messageType == M.messageType else {
            throw BPCError.messageTypeMismatch(expected: M.messageType, got: messageType)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(M.self, from: payload)
    }
}

/// Handler for incoming messages on a connection
public typealias MessageHandler = @Sendable (MessageEnvelope) async throws -> MessageEnvelope?

/// Internal class to manage socket lifecycle with proper cleanup
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
        // Get the raw fd and close it manually
        socket!.unsafe { fd in
            _ = Glibc.close(fd)
        }
        self.socket = nil
    }
}

/// Represents a bidirectional IPC connection
public actor BPCConnection {
    private let socketHolder: SocketHolder
    private let handler: MessageHandler?
    private var isActive: Bool = true

    /// Create a connection wrappping an existing socket.
    public init(socket: consuming SocketCapability, handler: MessageHandler? = nil) {
        self.socketHolder = SocketHolder(socket: socket)
        self.handler = handler
    }

    /// Sends a message over the connection.
    public func send(_ envelope: MessageEnvelope) async throws {
        guard isActive else {
            throw BPCError.connectionClosed
        }

        // Wire format:
        //   Fixed header (256 bytes):
        //     [payloadLength: UInt32]         // 4 bytes at offset 0
        //     [messageTypeLength: UInt16]     // 2 bytes at offset 4
        //     [descriptorCount: UInt8]        // 1 byte at offset 6
        //     [version: UInt8]                // 1 byte at offset 7
        //     [messageType: char[248]]        // 248 bytes at offset 8
        //   Payload:
        //     [payload: bytes]
        //   Fixed trailer (256 bytes):
        //     [reserved: char[256]]           // Reserved for future use
        //   Descriptors via control message (if count > 0)

        let messageTypeData = Data(envelope.messageType.utf8)
        guard messageTypeData.count <= 248 else {
            throw BPCError.messageTypeTooLong
        }

        // Build fixed 256-byte header
        var header = Data(count: 256)

        // payloadLength: UInt32 at offset 0
        var payloadLength = UInt32(envelope.payload.count).bigEndian
        header.replaceSubrange(0..<4, with: Data(bytes: &payloadLength, count: 4))

        // messageTypeLength: UInt16 at offset 4
        var messageTypeLength = UInt16(messageTypeData.count).bigEndian
        header.replaceSubrange(4..<6, with: Data(bytes: &messageTypeLength, count: 2))

        // descriptorCount: UInt8 at offset 6
        let descriptorCount = UInt8(min(envelope.descriptors.count, 255))
        header[6] = descriptorCount

        // version: UInt8 at offset 7
        header[7] = 0  // Protocol version 0

        // messageType: char[248] at offset 8
        header.replaceSubrange(8..<(8 + messageTypeData.count), with: messageTypeData)

        // Build complete payload: fixed header + payload + fixed trailer
        var completePayload = header
        completePayload.append(envelope.payload)

        // Append fixed 256-byte trailer (reserved for future use)
        let trailer = Data(count: 256)
        completePayload.append(trailer)

        // Send everything in a single sendmsg call (works with or without descriptors)
        try socketHolder.withSocket { socket in
            try socket.sendDescriptors(envelope.descriptors, payload: completePayload)
        } ?? { throw BPCError.connectionClosed }()
    }

    /// Send a message and wait for a response
    public func sendAndReceive(_ envelope: MessageEnvelope) async throws -> MessageEnvelope {
        try await send(envelope)
        return try await receive()
    }

    /// Receive a message from the connection
    public func receive() async throws -> MessageEnvelope {
        guard isActive else {
            throw BPCError.connectionClosed
        }

        return try socketHolder.withSocket { socket in
            // Receive everything in a single recvmsg call (fixed header + payload + trailer + descriptors)
            // Max buffer: 256-byte header + up to 1MB payload + 256-byte trailer
            let maxBufferSize = 256 + (1024 * 1024) + 256
            let (completeData, descriptors) = try socket.recvDescriptors(
                maxDescriptors: 255,  // Max descriptor count
                bufferSize: maxBufferSize
            )

            // Parse fixed 256-byte header
            guard completeData.count >= 256 else {
                throw BPCError.invalidMessageFormat
            }

            // payloadLength: UInt32 at offset 0
            let payloadLengthBytes = Data(completeData[0..<4])
            let payloadLength = payloadLengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // messageTypeLength: UInt16 at offset 4
            let messageTypeLengthBytes = Data(completeData[4..<6])
            let messageTypeLength = messageTypeLengthBytes.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }

            // descriptorCount: UInt8 at offset 6
            let descriptorCount = completeData[6]

            // version: UInt8 at offset 7
            let version = completeData[7]
            guard version == 0 else {
                throw BPCError.unsupportedVersion(version)
            }

            // messageType: char[248] at offset 8
            guard messageTypeLength <= 248 else {
                throw BPCError.invalidMessageFormat
            }
            let messageTypeData = completeData[8..<(8 + Int(messageTypeLength))]
            guard let messageType = String(data: messageTypeData, encoding: .utf8) else {
                throw BPCError.invalidMessageFormat
            }

            // Calculate expected total size: 256-byte header + payload + 256-byte trailer
            let expectedTotalSize = 256 + Int(payloadLength) + 256
            guard completeData.count == expectedTotalSize else {
                throw BPCError.invalidMessageFormat
            }

            // Verify descriptor count matches
            guard descriptors.count == Int(descriptorCount) else {
                throw BPCError.invalidMessageFormat
            }

            // Extract payload (between header and trailer)
            // Payload starts at offset 256, length is payloadLength
            let payloadStart = 256
            let payloadEnd = payloadStart + Int(payloadLength)
            let payload = completeData[payloadStart..<payloadEnd]

            // Trailer starts at payloadEnd and is 256 bytes (reserved for future use)
            // let trailer = completeData[payloadEnd..<(payloadEnd + 256)]

            return MessageEnvelope(payload: Data(payload), messageType: messageType, descriptors: descriptors)
        } ?? { throw BPCError.connectionClosed }()
    }

    /// Connect.
    public static func connect(path: String) throws -> Self {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )

        let address = try UnixSocketAddress(path: path)
        try socket.connect(address: address)

        return Self(socket: socket)
    }

    /// Start handling incoming messages
    public func start() async throws {
        guard let handler = handler else {
            throw BPCError.noHandlerConfigured
        }

        while isActive {
            do {
                let incoming = try await receive()
                let response = try await handler(incoming)

                if let response = response {
                    try await send(response)
                }
            } catch {
                // Connection errors should stop the handler
                isActive = false
                throw error
            }
        }
    }

    /// Close the connection
    public func close() {
        isActive = false
        socketHolder.close()
    }
}

/// Listens for incoming IPC connections
public actor BSDListener {
    private let socketHolder: SocketHolder
    private let handler: MessageHandler
    private var isActive: Bool = true

    /// Create a listener on a Unix domain socket path
    public static func unix(path: String, handler: @escaping MessageHandler) throws -> BSDListener {
        let socket = try SocketCapability.socket(
            domain: .unix,
            type: [.stream, .cloexec],
            protocol: .default
        )

        let address = try UnixSocketAddress(path: path)
        try socket.bind(address: address)
        try socket.listen(backlog: 128)

        return BSDListener(socket: socket, handler: handler)
    }

    private init(socket: consuming SocketCapability, handler: @escaping MessageHandler) {
        self.socketHolder = SocketHolder(socket: socket)
        self.handler = handler
    }

    /// Accept a single connection
    public func accept() async throws -> BPCConnection {
        guard isActive else {
            throw BPCError.listenerClosed
        }

        guard let clientSocket = try socketHolder.withSocket({ socket in
            return try socket.accept()
        }) else {
            throw BPCError.listenerClosed
        }

        return BPCConnection(socket: clientSocket, handler: handler)
    }

    /// Start accepting connections and spawn tasks to handle them
    public func start() async throws {
        while isActive {
            let connection = try await accept()

            // Spawn a task to handle this connection
            Task {
                try await connection.start()
            }
        }
    }

    /// Stop accepting new connections
    public func stop() {
        isActive = false
        socketHolder.close()
    }
}

// MARK: - Errors

public enum BPCError: Error, Sendable {
    case connectionClosed
    case listenerClosed
    case noHandlerConfigured
    case invalidMessageFormat
    case messageTypeMismatch(expected: String, got: String)
    case messageTypeTooLong
    case unsupportedVersion(UInt8)
    case invalidAddress
}