/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Descriptors

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
}

// MARK: - MessageID

/// The set of message types exchanged over a BPC connection.
public enum MessageID: UInt32, Sendable {
    /// Liveness probe sent by the client.
    case ping           = 1
    /// Response to a ``ping``.
    case pong           = 2
    /// Requests a name lookup from the server.
    case lookup         = 3
    /// Server reply to a ``lookup``.
    case lookupReply    = 4
    /// Requests a subscription to server-side events.
    case subscribe      = 5
    /// Server acknowledgement of a ``subscribe``.
    case subscribeAck   = 6
    /// An unsolicited event pushed by the server.
    case event          = 7
    /// Indicates an error condition.
    case error          = 255
}
