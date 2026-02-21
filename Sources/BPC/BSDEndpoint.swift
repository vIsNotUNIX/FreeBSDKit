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
import Capsicum

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
    /// The current connection state.
    ///
    /// Check this to determine if the endpoint is ready to use:
    /// - `.idle`: Need to call `start()`
    /// - `.running`: Active and ready
    /// - `.stopped`: Connection closed, cannot be reused
    var connectionState: ConnectionState { get }

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
    ///
    /// - Parameters:
    ///   - message: The request message to send
    ///   - timeout: Optional timeout duration. If `nil`, waits indefinitely. If provided and exceeded, throws ``BPCError/timeout``
    /// - Returns: The reply message with matching correlation ID
    /// - Throws: ``BPCError/timeout`` if timeout is specified and exceeded
    func request(_ message: Message, timeout: Duration?) async throws -> Message

    /// Sends a reply to a previously received request.
    ///
    /// Automatically copies the correlation ID from the original request to ensure
    /// the reply is routed back to the waiting caller. Use this instead of ``send(_:)``
    /// when responding to a request.
    ///
    /// - Parameters:
    ///   - request: The original request message to reply to
    ///   - id: The message ID for the reply (e.g., `.lookupReply`, `.pong`)
    ///   - payload: Optional payload data for the reply
    ///   - descriptors: Optional file descriptors to send with the reply
    func reply(
        to request: Message,
        id: MessageID,
        payload: Data,
        descriptors: [OpaqueDescriptorRef]
    ) async throws

    /// Sends a reply using a reply handle from a previously received request.
    ///
    /// Use this when you don't want to keep the entire message around:
    ///
    /// ```swift
    /// let request = try await endpoint.receive()
    /// let handle = request.replyHandle
    /// // ... process request ...
    /// try await endpoint.reply(to: handle, id: .pong, payload: data)
    /// ```
    ///
    /// - Parameters:
    ///   - handle: Reply handle extracted from the original request
    ///   - id: The message ID for the reply
    ///   - payload: Optional payload data for the reply
    ///   - descriptors: Optional file descriptors to send with the reply
    func reply(
        to handle: ReplyHandle,
        id: MessageID,
        payload: Data,
        descriptors: [OpaqueDescriptorRef]
    ) async throws

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

/// A ``BPCEndpoint`` backed by a BSD Unix-domain SEQPACKET socket.
///
/// This endpoint is specifically designed for SOCK_SEQPACKET which provides:
/// - Connection-oriented communication (like STREAM)
/// - Message boundary preservation (like DATAGRAM)
/// - Reliable, ordered delivery
///
/// Obtain an instance via ``BSDClient`` or ``pair()``.
/// After calling ``start()``, use ``send(_:)`` and ``request(_:)`` to write
/// to the wire, and ``messages()`` to consume inbound messages.
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

    // MARK: - Connection State

    public var connectionState: ConnectionState {
        state
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
    ///
    /// - Parameters:
    ///   - message: The request message to send
    ///   - timeout: Optional timeout duration. If `nil`, waits indefinitely. If provided and exceeded, throws ``BPCError/timeout``
    /// - Returns: The reply message with matching correlation ID
    /// - Throws: ``BPCError/timeout`` if timeout is specified and exceeded
    public func request(_ message: Message, timeout: Duration? = nil) async throws -> Message {
        var outgoing = message
        outgoing.correlationID = nextCorrelationID
        let correlationID = nextCorrelationID
        nextCorrelationID &+= 1

        try await send(outgoing)

        return try await withCheckedThrowingContinuation { continuation in
            pendingReplies[correlationID] = continuation

            // Start a timeout task if timeout is specified
            if let timeout = timeout {
                Task {
                    try? await Task.sleep(for: timeout)
                    if let pending = pendingReplies.removeValue(forKey: correlationID) {
                        pending.resume(throwing: BPCError.timeout)
                    }
                }
            }
        }
    }

    /// Sends a reply to a previously received request.
    ///
    /// Automatically copies the correlation ID from the original request message.
    /// This ensures the reply is routed back to the caller waiting in `request()`.
    public func reply(
        to request: Message,
        id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) async throws {
        let replyMessage = Message(
            id: id,
            correlationID: request.correlationID,
            payload: payload,
            descriptors: descriptors
        )
        try await send(replyMessage)
    }

    /// Sends a reply using a reply handle from a previously received request.
    ///
    /// Use this when you don't want to keep the entire message around:
    ///
    /// ```swift
    /// let request = try await endpoint.receive()
    /// let handle = request.replyHandle
    /// // ... process request ...
    /// try await endpoint.reply(to: handle, id: .pong, payload: data)
    /// ```
    public func reply(
        to handle: ReplyHandle,
        id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) async throws {
        let replyMessage = Message(
            id: id,
            correlationID: handle.correlationID,
            payload: payload,
            descriptors: descriptors
        )
        try await send(replyMessage)
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

    // MARK: - Pair

    /// Creates a pair of connected ``BSDEndpoint`` instances using `socketpair(2)`.
    ///
    /// The returned endpoints are bidirectionally connected SEQPACKET sockets ready
    /// for local IPC. Both are unstarted; call ``start()`` on each before exchanging
    /// messages.
    ///
    /// Each endpoint gets its own independent I/O queue to avoid serialization bottlenecks
    /// and potential deadlocks when the endpoints communicate with each other.
    ///
    /// - Parameters:
    ///   - firstQueue: Optional custom DispatchQueue for the first endpoint's I/O operations.
    ///                 If `nil`, a default queue is created.
    ///   - secondQueue: Optional custom DispatchQueue for the second endpoint's I/O operations.
    ///                  If `nil`, a default queue is created.
    /// - Returns: A tuple of two connected SEQPACKET endpoints, each with its own I/O queue.
    /// - Throws: A system error if the socketpair cannot be created.
    public static func pair(
        firstQueue: DispatchQueue? = nil,
        secondQueue: DispatchQueue? = nil
    ) throws -> (BSDEndpoint, BSDEndpoint) {
        let socketPair = try SocketCapability.socketPair(
            domain: .unix,
            type: [.seqpacket, .cloexec],
            protocol: .default
        )
        return (BSDEndpoint(socket: socketPair.first, ioQueue: firstQueue),
                BSDEndpoint(socket: socketPair.second, ioQueue: secondQueue))
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
    //   [payloadLength: UInt32]     4 bytes  offset  8  (0 if payload is out-of-line)
    //   [descriptorCount: UInt8]    1 byte   offset 12
    //   [version: UInt8]            1 byte   offset 13
    //   [flags: UInt8]              1 byte   offset 14
    //     - bit 0: hasOOLPayload (1 if payload sent via shared memory)
    //     - bits 1-7: reserved
    //   [reserved: UInt8[241]]    241 bytes  offset 15
    //
    // Trailer (256 bytes):
    //   [descriptorKinds[0..254]]  255 bytes  offset 0-254
    //     - Each byte encodes the DescriptorKind for the corresponding descriptor
    //     - Value 255 indicates an out-of-line payload descriptor
    //   [reserved: UInt8]           1 byte   offset 255
    //
    // Out-of-line (OOL) payload:
    //   When payload exceeds MAX_INLINE_PAYLOAD bytes, it's sent via shared memory:
    //   1. A SharedMemoryCapability is created
    //   2. Payload is written to shared memory
    //   3. The shm descriptor is prepended to the descriptor list
    //   4. Its kind in the trailer is marked as oolPayloadWireValue (255)
    //   5. payloadLength is set to 0 and hasOOLPayload flag is set

    /// Maximum inline payload size before switching to out-of-line shared memory.
    ///
    /// Queried from `net.local.seqpacket.maxseqpacket` sysctl at first use.
    /// Typically 64KB (65536 bytes) on FreeBSD. Messages larger than this are
    /// automatically sent via anonymous shared memory.
    private static let MAX_INLINE_PAYLOAD: Int = {
        // Account for header (256) + trailer (256) in the total message
        let overhead = 512
        let kernelMax = SocketLimits.maxSeqpacketSize()

        // Leave some headroom for the wire format overhead
        return max(kernelMax - overhead, 1024)
    }()

    nonisolated private func socketSend(_ message: Message) throws {
        var payload = message.payload
        var descriptors = message.descriptors
        var flags: UInt8 = 0

        // Handle out-of-line payload if needed
        if payload.count > Self.MAX_INLINE_PAYLOAD {
            // Create anonymous shared memory for the payload
            // This is capability-mode safe (no namespace access required)
            let shm = try SharedMemoryCapability.anonymous(flags: .readWrite)

            // Set size and map
            try shm.setSize(payload.count)
            let region = try shm.map(
                size: payload.count,
                protection: [.read, .write],
                flags: [.shared]
            )

            // Copy payload to shared memory
            payload.withUnsafeBytes { payloadBytes in
                UnsafeMutableRawPointer(mutating: region.base).copyMemory(
                    from: payloadBytes.baseAddress!,
                    byteCount: payload.count
                )
            }

            // Limit the shared memory descriptor to read-only rights before sending
            // This ensures the receiver cannot modify the payload
            let readOnlyRights = CapsicumRightSet(rights: [
                .mmapR,      // Allow read-only mmap
                .fstat,      // Allow fstat to get size
                .seek        // Allow lseek for reading
            ])
            _ = shm.limit(rights: readOnlyRights)

            // Create OpaqueDescriptorRef for the shm with .shm kind
            let shmRef = OpaqueDescriptorRef(shm.take(), kind: .shm)

            // Prepend to descriptors list
            descriptors.insert(shmRef, at: 0)

            // Clear inline payload and set OOL flag
            payload = Data()
            flags |= 0x01  // hasOOLPayload
        }

        // Build header
        var header = Data(count: 256)

        var messageID = message.id.rawValue
        header.replaceSubrange(0..<4, with: Data(bytes: &messageID, count: 4))

        var correlationID = message.correlationID
        header.replaceSubrange(4..<8, with: Data(bytes: &correlationID, count: 4))

        var payloadLength = UInt32(payload.count)
        header.replaceSubrange(8..<12, with: Data(bytes: &payloadLength, count: 4))

        header[12] = UInt8(min(descriptors.count, 255))
        header[13] = 0  // version
        header[14] = flags

        // Build trailer with descriptor kinds
        var trailer = Data(count: 256)
        for (index, descriptor) in descriptors.enumerated() {
            guard index < 255 else { break }

            // If this is the first descriptor and OOL flag is set, mark it specially
            if index == 0 && (flags & 0x01) != 0 {
                trailer[index] = DescriptorKind.oolPayloadWireValue
            } else {
                trailer[index] = descriptor.kind.wireValue
            }
        }

        // Assemble wire data
        var wireData = header
        wireData.append(payload)
        wireData.append(trailer)

        try socketHolder.withSocketOrThrow { socket in
            try socket.sendDescriptors(descriptors, payload: wireData)
        }
    }

    nonisolated private func socketReceive() throws -> Message {
        // Max buffer: 256-byte header + max payload + 256-byte trailer
        let maxBufferSize = 256 + Self.MAX_INLINE_PAYLOAD + 256

        let (wireData, receivedDescriptors) = try socketHolder.withSocketOrThrow { socket in
            try socket.recvDescriptors(maxDescriptors: 255, bufferSize: maxBufferSize)
        }

        guard wireData.count >= 512 else {  // At least header + trailer
            throw BPCError.invalidMessageFormat
        }

        // Parse header
        let messageIDRaw = Data(wireData[0..<4]).withUnsafeBytes { $0.load(as: UInt32.self) }
        let messageID = MessageID(rawValue: messageIDRaw)

        let correlationID = Data(wireData[4..<8]).withUnsafeBytes { $0.load(as: UInt32.self) }
        let payloadLength = Data(wireData[8..<12]).withUnsafeBytes { $0.load(as: UInt32.self) }
        let descriptorCount = wireData[12]
        let version = wireData[13]
        let flags = wireData[14]

        guard version == 0 else {
            throw BPCError.unsupportedVersion(version)
        }

        let expectedTotal = 256 + Int(payloadLength) + 256
        guard wireData.count == expectedTotal else {
            throw BPCError.invalidMessageFormat
        }

        guard receivedDescriptors.count == Int(descriptorCount) else {
            throw BPCError.invalidMessageFormat
        }

        // Extract trailer (last 256 bytes)
        let trailerStart = wireData.count - 256
        let trailer = wireData[trailerStart..<wireData.count]

        // Decode descriptor kinds from trailer and set them on the descriptors
        var descriptors = receivedDescriptors
        for (index, descriptor) in descriptors.enumerated() {
            guard index < 255 else { break }
            let kindValue = trailer[index]
            if kindValue != DescriptorKind.oolPayloadWireValue {
                descriptor.kind = DescriptorKind.fromWireValue(kindValue)
            }
        }

        // Handle out-of-line payload
        var payload: Data
        let hasOOLPayload = (flags & 0x01) != 0

        if hasOOLPayload {
            guard !descriptors.isEmpty else {
                throw BPCError.invalidMessageFormat
            }

            // First descriptor should be the OOL payload shm
            guard trailer[0] == DescriptorKind.oolPayloadWireValue else {
                throw BPCError.invalidMessageFormat
            }

            let shmDescriptor = descriptors.removeFirst()

            // Map the shared memory and read the payload
            guard let shmFD = shmDescriptor.toBSDValue() else {
                throw BPCError.invalidMessageFormat
            }

            // Get the size of the shm
            var stat = stat()
            guard Glibc.fstat(shmFD, &stat) == 0 else {
                try BSDError.throwErrno(errno)
            }

            let shmSize = Int(stat.st_size)
            guard shmSize > 0 else {
                throw BPCError.invalidMessageFormat
            }

            // Map and read
            let ptr = Glibc.mmap(nil, shmSize, PROT_READ, MAP_SHARED, shmFD, 0)
            guard ptr != MAP_FAILED else {
                try BSDError.throwErrno(errno)
            }

            defer {
                Glibc.munmap(ptr, shmSize)
            }

            payload = Data(bytes: ptr!, count: shmSize)
        } else {
            // Inline payload
            payload = Data(wireData[256..<(256 + Int(payloadLength))])
        }

        return Message(
            id: messageID,
            correlationID: correlationID,
            payload: payload,
            descriptors: descriptors
        )
    }
}
