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
    private var pendingTimeouts: [UInt32: Task<Void, Never>] = [:]
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
        guard state == .idle else { return }
        state = .running
        let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
        messageStream = stream
        incomingContinuation = continuation

        receiveLoopTask = Task {
            await receiveLoop()
        }
    }

    public func stop() {
        guard state != .stopped else { return }
        state = .stopped
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        socketHolder.close()
        teardown(throwing: BPCError.stopped)
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
        // Increment and skip 0 (reserved for unsolicited messages)
        nextCorrelationID = nextCorrelationID &+ 1
        if nextCorrelationID == 0 {
            nextCorrelationID = 1
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Register continuation BEFORE sending to avoid lost-reply race
                pendingReplies[correlationID] = continuation

                // Start a timeout task if timeout is specified
                if let timeout = timeout {
                    let timeoutTask = Task { [correlationID] in
                        try? await Task.sleep(for: timeout)
                        await self.handleTimeout(correlationID)
                    }
                    pendingTimeouts[correlationID] = timeoutTask
                }

                // Check for early cancellation before sending
                if Task.isCancelled {
                    Task { await self.failPendingRequest(correlationID, error: CancellationError()) }
                    return
                }

                // Send in background task; clean up on failure
                Task {
                    do {
                        try await self.send(outgoing)
                    } catch {
                        await self.failPendingRequest(correlationID, error: error)
                    }
                }
            }
        } onCancel: {
            Task { await self.failPendingRequest(correlationID, error: CancellationError()) }
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

    /// Sends a reply using a reply token from a previously received request.
    ///
    /// Use this when you don't want to keep the entire message around:
    ///
    /// ```swift
    /// let request = try await endpoint.receive()
    /// let token = request.replyToken
    /// // ... process request ...
    /// try await endpoint.reply(to: token, id: .pong, payload: data)
    /// ```
    public func reply(
        to token: ReplyToken,
        id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) async throws {
        let replyMessage = Message(
            id: id,
            correlationID: token.correlationID,
            payload: payload,
            descriptors: descriptors
        )
        try await send(replyMessage)
    }

    /// Returns the stream of unsolicited inbound messages.
    ///
    /// Can only be claimed by one task. Throws `.notStarted` if ``start()`` has
    /// not been called, `.stopped` if ``stop()`` has been called, or
    /// `.streamAlreadyClaimed` if already claimed.
    public func messages() throws -> AsyncStream<Message> {
        switch state {
        case .idle:    throw BPCError.notStarted
        case .stopped: throw BPCError.stopped
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

    private func handleTimeout(_ id: UInt32) async {
        pendingTimeouts.removeValue(forKey: id)
        if let pending = pendingReplies.removeValue(forKey: id) {
            pending.resume(throwing: BPCError.timeout)
        }
    }

    private func failPendingRequest(_ id: UInt32, error: Error) async {
        if let timeoutTask = pendingTimeouts.removeValue(forKey: id) {
            timeoutTask.cancel()
        }
        if let pending = pendingReplies.removeValue(forKey: id) {
            pending.resume(throwing: error)
        }
    }

    /// Routes an incoming message to a waiting `request()` caller or the unsolicited stream.
    private func dispatch(_ message: Message) {
        if message.correlationID != 0 {
            // Reply message - find the pending request
            if let continuation = pendingReplies.removeValue(forKey: message.correlationID) {
                // Cancel and remove the timeout task if it exists
                if let timeoutTask = pendingTimeouts.removeValue(forKey: message.correlationID) {
                    timeoutTask.cancel()
                }
                continuation.resume(returning: message)
            }
            // Else: orphaned reply (caller cancelled) - drop it
        } else {
            // Unsolicited message
            incomingContinuation?.yield(message)
        }
    }

    private func receiveLoop() async {
        defer {
            // Ensure cleanup if loop exits unexpectedly
            if state == .running {
                state = .stopped
                socketHolder.close()
                teardown(throwing: BPCError.disconnected)
            }
        }

        while !Task.isCancelled {
            do {
                let message = try await receiveFromSocket()
                dispatch(message)
            } catch {
                state = .stopped
                socketHolder.close()
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
        // Cancel all pending timeout tasks
        for (_, task) in pendingTimeouts {
            task.cancel()
        }
        pendingTimeouts.removeAll()

        // Fail all pending replies
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
    // IMPORTANT: Version 0 uses host-endian encoding for multi-byte fields.
    // Endpoints MUST be same-host, same-ABI. Do NOT persist frames or send
    // across architectures. This is acceptable for local Unix-domain IPC only.
    //
    // Header (256 bytes):
    //   - messageID (UInt32):        4 bytes at offset 0  (host-endian)
    //   - correlationID (UInt32):    4 bytes at offset 4  (host-endian)
    //   - payloadLength (UInt32):    4 bytes at offset 8  (host-endian, 0 if OOL)
    //   - descriptorCount (UInt8):   1 byte  at offset 12 (max 254)
    //   - version (UInt8):           1 byte  at offset 13 (currently 0)
    //   - flags (UInt8):             1 byte  at offset 14
    //       - bit 0: hasOOLPayload (1 if payload sent via shared memory)
    //       - bits 1-7: reserved
    //   - reserved:                241 bytes at offset 15-255
    //
    // Trailer (256 bytes):
    //   - descriptorKinds: 254 bytes at offset 0-253 (one per descriptor)
    //       - Each byte encodes DescriptorKind.wireValue
    //       - Value 255 marks the out-of-line payload descriptor (index 0 only)
    //   - reserved:          2 bytes at offset 254-255
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
    /// Queried from the `net.local.seqpacket.maxseqpacket` sysctl. Typically 64KB
    /// on FreeBSD. Messages exceeding this limit are automatically sent via
    /// anonymous shared memory with the payload descriptor passed out-of-band.
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
        var shmDescriptor: Int32? = nil
        if payload.count > Self.MAX_INLINE_PAYLOAD {
            // Check descriptor limit (254 max, OOL adds one more)
            guard descriptors.count < 254 else {
                throw BPCError.tooManyDescriptors(descriptors.count + 1)
            }
            // Create anonymous shared memory (capability-mode safe)
            let shm = try SharedMemoryCapability.anonymous(accessMode: .readWrite)

            // Set size and map
            try shm.setSize(payload.count)
            let region = try shm.map(
                size: payload.count,
                protection: [.read, .write],
                flags: [.shared]
            )

            // Copy payload to shared memory
            try payload.withUnsafeBytes { payloadBytes in
                guard let source = payloadBytes.baseAddress else {
                    throw POSIXError(.EINVAL)
                }
                UnsafeMutableRawPointer(mutating: region.base).copyMemory(
                    from: source,
                    byteCount: payload.count
                )
            }

            // Unmap after copying
            try region.unmap()

            // Limit to read-only rights before sending to receiver
            let readOnlyRights = CapsicumRightSet(rights: [
                .mmapR,      // Allow read-only mmap
                .fstat,      // Allow fstat to get size
                .seek        // Allow lseek for reading
            ])
            _ = shm.limit(rights: readOnlyRights)

            // Track fd for cleanup on send failure
            shmDescriptor = shm.take()
            let shmRef = OpaqueDescriptorRef(shmDescriptor!, kind: .shm)

            // Prepend OOL descriptor and set flag
            descriptors.insert(shmRef, at: 0)
            payload = Data()
            flags |= 0x01
        } else {
            // Validate descriptor count (254 max)
            guard descriptors.count <= 254 else {
                throw BPCError.tooManyDescriptors(descriptors.count)
            }
        }

        // Build header
        var header = Data(count: 256)

        var messageID = message.id.rawValue
        header.replaceSubrange(0..<4, with: Data(bytes: &messageID, count: 4))

        var correlationID = message.correlationID
        header.replaceSubrange(4..<8, with: Data(bytes: &correlationID, count: 4))

        var payloadLength = UInt32(payload.count)
        header.replaceSubrange(8..<12, with: Data(bytes: &payloadLength, count: 4))

        // Descriptor count already validated above (254 max)
        header[12] = UInt8(descriptors.count)
        header[13] = 0  // version
        header[14] = flags

        // Build trailer with descriptor kinds
        var trailer = Data(count: 256)
        for (index, descriptor) in descriptors.enumerated() {
            guard index < 254 else { break }
            if index == 0 && (flags & 0x01) != 0 {
                trailer[index] = DescriptorKind.oolPayloadWireValue
            } else {
                trailer[index] = descriptor.kind.wireValue
            }
        }

        // Assemble and send
        var wireData = header
        wireData.append(payload)
        wireData.append(trailer)

        do {
            try socketHolder.withSocketOrThrow { socket in
                try socket.sendDescriptors(descriptors, payload: wireData)
            }
        } catch {
            // Clean up OOL descriptor if send failed
            if let fd = shmDescriptor {
                _ = Glibc.close(fd)
            }
            throw error
        }
    }

    nonisolated private func socketReceive() throws -> Message {
        // Max buffer: 256-byte header + max payload + 256-byte trailer
        let maxBufferSize = 256 + Self.MAX_INLINE_PAYLOAD + 256

        let (wireData, receivedDescriptors) = try socketHolder.withSocketOrThrow { socket in
            try socket.recvDescriptors(maxDescriptors: 254, bufferSize: maxBufferSize)
        }

        guard wireData.count >= 512 else {  // At least header + trailer
            throw BPCError.invalidMessageFormat
        }

        // Parse header
        let messageIDRaw = wireData.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
        }
        let messageID = MessageID(rawValue: messageIDRaw)

        let correlationID = wireData.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)
        }
        let payloadLength = wireData.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
        }
        let descriptorCount = wireData[12]
        let version = wireData[13]
        let flags = wireData[14]

        guard version == 0 else {
            throw BPCError.unsupportedVersion(version)
        }

        // Validate descriptor count (max 254)
        guard descriptorCount <= 254 else {
            throw BPCError.invalidMessageFormat
        }

        // Validate OOL payload flag consistency
        let hasOOLPayload = (flags & 0x01) != 0
        if hasOOLPayload {
            // If OOL flag is set, inline payload length must be 0
            guard payloadLength == 0 else {
                throw BPCError.invalidMessageFormat
            }
            // OOL requires at least one descriptor (the shm)
            guard descriptorCount >= 1 else {
                throw BPCError.invalidMessageFormat
            }
        }

        let expectedTotal = 256 + Int(payloadLength) + 256
        guard wireData.count == expectedTotal else {
            throw BPCError.invalidMessageFormat
        }

        guard receivedDescriptors.count == Int(descriptorCount) else {
            throw BPCError.invalidMessageFormat
        }

        // Extract trailer
        let trailerStart = wireData.count - 256
        let trailer = wireData[trailerStart..<wireData.count]

        // Decode descriptor kinds from trailer
        var descriptors = receivedDescriptors
        for (index, descriptor) in descriptors.enumerated() {
            guard index < 254 else { break }
            let kindValue = trailer[index]

            // Only index 0 may have OOL marker (255) when hasOOLPayload
            if kindValue == DescriptorKind.oolPayloadWireValue {
                guard hasOOLPayload && index == 0 else {
                    throw BPCError.invalidMessageFormat
                }
            } else {
                descriptor.kind = DescriptorKind.fromWireValue(kindValue)
            }
        }

        // Handle out-of-line payload
        var payload: Data

        if hasOOLPayload {
            guard !descriptors.isEmpty else {
                throw BPCError.invalidMessageFormat
            }

            guard trailer[0] == DescriptorKind.oolPayloadWireValue else {
                throw BPCError.invalidMessageFormat
            }

            let shmDescriptor = descriptors.removeFirst()

            // Take ownership of the fd to ensure explicit cleanup
            guard let shmFD = shmDescriptor.take() else {
                throw BPCError.invalidMessageFormat
            }

            defer {
                Glibc.close(shmFD)
            }

            var stat = stat()
            guard Glibc.fstat(shmFD, &stat) == 0 else {
                try BSDError.throwErrno(errno)
            }

            let shmSize = Int(stat.st_size)
            guard shmSize > 0 else {
                throw BPCError.invalidMessageFormat
            }

            let ptr = Glibc.mmap(nil, shmSize, PROT_READ, MAP_SHARED, shmFD, 0)
            guard ptr != MAP_FAILED, let mappedPtr = ptr else {
                try BSDError.throwErrno(errno)
            }

            defer {
                Glibc.munmap(mappedPtr, shmSize)
            }

            payload = Data(bytes: mappedPtr, count: shmSize)
        } else {
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
