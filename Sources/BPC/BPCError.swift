/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - BPCError

/// Errors produced by the BPC transport layer.
public enum BPCError: Error, Sendable, Equatable {
    /// The underlying socket connection was lost due to remote disconnect.
    case disconnected
    /// The endpoint was explicitly stopped by calling `stop()`.
    case stopped
    /// The listener socket has been closed.
    case listenerClosed
    /// ``BPCEndpoint/start()`` or ``BPCListener/start()`` has not been called.
    case notStarted
    /// The async stream has already been claimed by another task.
    case streamAlreadyClaimed
    /// The received bytes do not conform to the BPC wire format.
    case invalidMessageFormat
    /// The wire header names a protocol version this implementation does not support.
    case unsupportedVersion(UInt8)
    /// A message arrived that was not valid in the current context.
    case unexpectedMessage(MessageID)
    /// An operation did not complete within the allowed time.
    case timeout
    /// Too many file descriptors in message (maximum is 254).
    case tooManyDescriptors(Int)
}

extension BPCError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "BPC connection lost (remote disconnect)"
        case .stopped:
            return "BPC endpoint stopped"
        case .listenerClosed:
            return "BPC listener socket closed"
        case .notStarted:
            return "BPC endpoint/listener not started - call start() first"
        case .streamAlreadyClaimed:
            return "BPC message stream already claimed by another task"
        case .invalidMessageFormat:
            return "Invalid BPC wire format"
        case .unsupportedVersion(let version):
            return "Unsupported BPC protocol version: \(version)"
        case .unexpectedMessage(let id):
            return "Unexpected BPC message: \(id)"
        case .timeout:
            return "BPC operation timed out"
        case .tooManyDescriptors(let count):
            return "Too many file descriptors (\(count)); maximum is 254 per message"
        }
    }
}
