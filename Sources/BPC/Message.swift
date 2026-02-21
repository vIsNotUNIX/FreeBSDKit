/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors

// MARK: - ReplyHandle

/// A lightweight token for replying to a received message.
///
/// Instead of holding onto the entire `Message`, extract a reply handle and use it later:
///
/// ```swift
/// let request = try await endpoint.receive()
/// let handle = request.replyHandle
///
/// // ... process request ...
///
/// try await endpoint.reply(to: handle, id: .pong, payload: data)
/// ```
public struct ReplyHandle: Sendable, Hashable {
    /// The correlation ID to echo back in the reply.
    public let correlationID: UInt32

    /// Creates a reply handle with the specified correlation ID.
    public init(correlationID: UInt32) {
        self.correlationID = correlationID
    }
}

// MARK: - Message

/// A unit of communication between a BPC client and server.
///
/// Each message carries a typed identifier, an optional binary payload, and optional
/// file descriptors. Correlation IDs tie request/reply pairs together: a value of `0`
/// indicates an unsolicited message; a non-zero value links a reply to the request
/// that originated it — the correlation ID is assigned by the sending ``BSDEndpoint``.
public struct Message: Sendable {

    /// Identifies the kind of message.
    public var id: MessageID

    /// Links a reply to its originating request.
    ///
    /// `0` means the message is unsolicited. Non-zero values are assigned automatically
    /// by ``BSDEndpoint/send(_:)`` and echoed back in the matching reply.
    public var correlationID: UInt32

    /// The message body, interpreted by the application layer.
    public var payload: Data

    /// File descriptors delivered alongside the payload over the Unix socket.
    public var descriptors: [OpaqueDescriptorRef]

    /// Creates a message with explicit field values.
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

    /// Returns a lightweight handle for replying to this message.
    ///
    /// Use this when you don't want to keep the entire message around:
    ///
    /// ```swift
    /// let request = try await endpoint.receive()
    /// let handle = request.replyHandle
    /// // Can discard the original request now
    /// try await endpoint.reply(to: handle, id: .pong)
    /// ```
    public var replyHandle: ReplyHandle {
        ReplyHandle(correlationID: correlationID)
    }

    /// Creates a message intended for a request/reply exchange.
    ///
    /// The sending ``BPCEndpoint`` assigns the correlation ID automatically;
    /// leave it at the default `0`.
    public static func request(
        _ id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(id: id, correlationID: 0, payload: payload, descriptors: descriptors)
    }

    /// Creates a one-way message that expects no reply.
    public static func notification(
        _ id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(id: id, correlationID: 0, payload: payload, descriptors: descriptors)
    }

    /// Creates a reply to a previously received request.
    ///
    /// Automatically copies the correlation ID from the original request to ensure
    /// proper routing. Use this when manually constructing reply messages.
    ///
    /// - Parameters:
    ///   - request: The original request message to reply to
    ///   - id: The message ID for the reply (e.g., `.lookupReply`, `.pong`)
    ///   - payload: Optional payload data for the reply
    ///   - descriptors: Optional file descriptors to send with the reply
    /// - Returns: A message with the same correlation ID as the request
    public static func reply(
        to request: Message,
        id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(
            id: id,
            correlationID: request.correlationID,
            payload: payload,
            descriptors: descriptors
        )
    }

    /// Creates a reply using a reply handle from a previously received request.
    ///
    /// Useful when you don't want to keep the entire message around:
    ///
    /// ```swift
    /// let request = try await endpoint.receive()
    /// let handle = request.replyHandle
    /// // ... later ...
    /// let reply = Message.reply(to: handle, id: .pong)
    /// try await endpoint.send(reply)
    /// ```
    ///
    /// - Parameters:
    ///   - handle: Reply handle extracted from the original request
    ///   - id: The message ID for the reply
    ///   - payload: Optional payload data for the reply
    ///   - descriptors: Optional file descriptors to send with the reply
    /// - Returns: A message with the correlation ID from the handle
    public static func reply(
        to handle: ReplyHandle,
        id: MessageID,
        payload: Data = Data(),
        descriptors: [OpaqueDescriptorRef] = []
    ) -> Message {
        Message(
            id: id,
            correlationID: handle.correlationID,
            payload: payload,
            descriptors: descriptors
        )
    }
}

// MARK: - MessageID

/// Identifies the kind of message exchanged over a BPC connection.
///
/// Use the predefined constants for standard BPC messages, or create your own:
///
/// ```swift
/// extension MessageID {
///     static let myCustomRequest = MessageID(rawValue: 100)
///     static let myCustomReply = MessageID(rawValue: 101)
/// }
///
/// let message = Message(id: .myCustomRequest, payload: data)
/// ```
public struct MessageID: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // MARK: Standard Message Types

    /// Liveness probe sent by the client.
    public static let ping = MessageID(rawValue: 1)

    /// Response to a ``ping``.
    public static let pong = MessageID(rawValue: 2)

    /// Requests a name lookup from the server.
    public static let lookup = MessageID(rawValue: 3)

    /// Server reply to a ``lookup``.
    public static let lookupReply = MessageID(rawValue: 4)

    /// Requests a subscription to server-side events.
    public static let subscribe = MessageID(rawValue: 5)

    /// Server acknowledgement of a ``subscribe``.
    public static let subscribeAck = MessageID(rawValue: 6)

    /// An unsolicited event pushed by the server.
    public static let event = MessageID(rawValue: 7)

    /// Indicates an error condition.
    public static let error = MessageID(rawValue: 255)
}
