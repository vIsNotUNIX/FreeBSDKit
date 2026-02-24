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
    private var nextCorrelationID: UInt64 = 1
    private var pendingReplies: [UInt64: CheckedContinuation<Message, Error>] = [:]
    private var pendingTimeouts: [UInt64: Task<Void, Never>] = [:]
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
        // 64-bit correlation ID - won't wrap in practice (~585 years at 1B msg/sec)
        let correlationID = nextCorrelationID
        nextCorrelationID += 1
        // Skip 0 (reserved for unsolicited messages)
        if nextCorrelationID == 0 { nextCorrelationID = 1 }

        var outgoing = message
        outgoing.correlationID = correlationID

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

    /// Returns the stream of unsolicited inbound messages (correlationID == 0).
    ///
    /// Reply messages (correlationID != 0) are automatically routed to the
    /// corresponding ``request(_:timeout:)`` caller and never appear here.
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

    private func handleTimeout(_ correlationID: UInt64) async {
        pendingTimeouts.removeValue(forKey: correlationID)
        if let pending = pendingReplies.removeValue(forKey: correlationID) {
            pending.resume(throwing: BPCError.timeout)
        }
    }

    private func failPendingRequest(_ correlationID: UInt64, error: Error) async {
        if let timeoutTask = pendingTimeouts.removeValue(forKey: correlationID) {
            timeoutTask.cancel()
        }
        if let pending = pendingReplies.removeValue(forKey: correlationID) {
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
            // Else: orphaned reply (caller cancelled or timed out) - drop it
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

    // MARK: - Wire Format I/O
    //
    // Wire format encoding/decoding is handled by WireFormat.swift.
    // This section handles the actual socket I/O and OOL payload management.

    /// Maximum inline payload size before switching to out-of-line shared memory.
    ///
    /// Queried from the `net.local.seqpacket.maxseqpacket` sysctl. Typically 64KB
    /// on FreeBSD. Messages exceeding this limit are automatically sent via
    /// anonymous shared memory with the payload descriptor passed out-of-band.
    private static let MAX_INLINE_PAYLOAD: Int = {
        // Account for header (256) + trailer (256) in the total message
        let overhead = 512
        let kernelMax = SocketLimits.maxSeqpacketSize()

        // Payload space is kernel max minus overhead, but never negative
        // If kernel max is very small, OOL will be used for most payloads
        let available = kernelMax - overhead
        return available > 0 ? available : 0
    }()

    nonisolated private func socketSend(_ message: Message) throws {
        var payload = message.payload
        var descriptors = message.descriptors
        var useOOL = false

        // Handle out-of-line payload if needed
        var shmDescriptor: Int32? = nil
        if payload.count > Self.MAX_INLINE_PAYLOAD {
            // Check descriptor limit (254 max, OOL adds one more)
            guard descriptors.count < WireFormat.maxDescriptors else {
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

            // Prepend OOL descriptor
            descriptors.insert(shmRef, at: 0)
            payload = Data()
            useOOL = true
        } else {
            // Validate descriptor count (254 max)
            guard descriptors.count <= WireFormat.maxDescriptors else {
                throw BPCError.tooManyDescriptors(descriptors.count)
            }
        }

        // Build wire message using WireFormat
        let header = WireHeader(
            messageID: message.id.rawValue,
            correlationID: message.correlationID,
            payloadLength: UInt32(payload.count),
            descriptorCount: UInt8(descriptors.count),
            flags: useOOL ? WireFormat.flagOOLPayload : 0
        )

        let descriptorKinds = descriptors.prefix(WireFormat.maxDescriptors).map { $0.kind.wireValue }
        let trailer = WireTrailer(descriptorKinds: Array(descriptorKinds))

        // Assemble wire data
        var wireData = header.encode()
        wireData.append(payload)
        wireData.append(trailer.encode(hasOOLPayload: useOOL))

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
        // Max buffer: header + max payload + trailer
        let maxBufferSize = WireFormat.headerSize + Self.MAX_INLINE_PAYLOAD + WireFormat.trailerSize

        let (wireData, receivedDescriptors) = try socketHolder.withSocketOrThrow { socket in
            try socket.recvDescriptors(maxDescriptors: WireFormat.maxDescriptors, bufferSize: maxBufferSize)
        }

        guard wireData.count >= WireFormat.minimumMessageSize else {
            throw BPCError.invalidMessageFormat
        }

        // Parse and validate header
        let header = try WireHeader.decode(from: wireData)
        try header.validate()

        // Validate total message size
        let expectedTotal = WireFormat.headerSize + Int(header.payloadLength) + WireFormat.trailerSize
        guard wireData.count == expectedTotal else {
            throw BPCError.invalidMessageFormat
        }

        // Validate descriptor count matches
        guard receivedDescriptors.count == Int(header.descriptorCount) else {
            throw BPCError.invalidMessageFormat
        }

        // Parse and validate trailer
        let trailerStart = wireData.count - WireFormat.trailerSize
        let trailerData = Data(wireData[trailerStart...])
        let trailer = try WireTrailer.decode(from: trailerData, descriptorCount: Int(header.descriptorCount))
        try trailer.validate(hasOOLPayload: header.hasOOLPayload)

        // Apply descriptor kinds from trailer
        var descriptors = receivedDescriptors
        for (index, kindValue) in trailer.descriptorKinds.enumerated() {
            guard index < descriptors.count else { break }
            if kindValue != DescriptorKind.oolPayloadWireValue {
                descriptors[index].kind = DescriptorKind.fromWireValue(kindValue)
            }
        }

        // Handle payload (inline or out-of-line)
        var payload: Data

        if header.hasOOLPayload {
            guard !descriptors.isEmpty else {
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
            let payloadStart = WireFormat.headerSize
            let payloadEnd = payloadStart + Int(header.payloadLength)
            payload = Data(wireData[payloadStart..<payloadEnd])
        }

        return Message(
            id: MessageID(rawValue: header.messageID),
            correlationID: header.correlationID,
            payload: payload,
            descriptors: descriptors
        )
    }
}
