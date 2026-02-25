/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors

// MARK: - Endpoint Protocol

/// The interface for an FPC connection endpoint.
///
/// An endpoint represents one side of an established socket connection. Obtain a
/// concrete implementation via ``FPCClient/connect(path:)``, then call ``start()``
/// before exchanging messages.
///
/// ## Lifecycle
/// 1. Call ``start()`` to begin the receive loop.
/// 2. Use ``send(_:)``, ``request(_:)``, and ``incoming()`` to exchange messages.
/// 3. Call ``stop()`` to tear down the connection and fail any pending callers.
public protocol Endpoint: Actor {
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
    ///   - timeout: Optional timeout duration. If `nil`, waits indefinitely. If provided and exceeded, throws ``FPCError/timeout``
    /// - Returns: The reply message with matching correlation ID
    /// - Throws: ``FPCError/timeout`` if timeout is specified and exceeded
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
    ///
    /// - Parameters:
    ///   - token: Reply token extracted from the original request
    ///   - id: The message ID for the reply
    ///   - payload: Optional payload data for the reply
    ///   - descriptors: Optional file descriptors to send with the reply
    func reply(
        to token: ReplyToken,
        id: MessageID,
        payload: Data,
        descriptors: [OpaqueDescriptorRef]
    ) async throws

    /// Returns the stream of unsolicited inbound messages (correlationID == 0).
    ///
    /// This stream only receives messages that are **not** replies to pending requests.
    /// Reply messages (correlationID != 0) are automatically routed to the corresponding
    /// ``request(_:timeout:)`` caller and never appear in this stream.
    ///
    /// Use this for:
    /// - Server-pushed events and notifications
    /// - Incoming requests that need handling
    /// - Any message not part of a request/reply exchange
    ///
    /// Can only be claimed by one task. The stream finishes when the connection
    /// is lost or ``stop()`` is called.
    ///
    /// - Throws: ``FPCError/notStarted`` if ``start()`` has not been called,
    ///           ``FPCError/stopped`` if ``stop()`` has been called,
    ///           ``FPCError/streamAlreadyClaimed`` if already claimed by another task.
    func incoming() throws -> AsyncStream<Message>
}
