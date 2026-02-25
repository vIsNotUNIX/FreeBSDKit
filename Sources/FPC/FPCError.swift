/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - FPCError

/// Errors produced by the FPC transport layer.
public enum FPCError: Error, Sendable, Equatable {
    /// The underlying socket connection was lost due to remote disconnect.
    case disconnected
    /// The endpoint was explicitly stopped by calling `stop()`.
    case stopped
    /// The listener socket has been closed.
    case listenerClosed
    /// ``FPCEndpoint/start()`` or ``FPCListener/start()`` has not been called.
    case notStarted
    /// The async stream has already been claimed by another task.
    case streamAlreadyClaimed
    /// The received bytes do not conform to the FPC wire format.
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

extension FPCError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "FPC connection lost (remote disconnect)"
        case .stopped:
            return "FPC endpoint stopped"
        case .listenerClosed:
            return "FPC listener socket closed"
        case .notStarted:
            return "FPC endpoint/listener not started - call start() first"
        case .streamAlreadyClaimed:
            return "FPC message stream already claimed by another task"
        case .invalidMessageFormat:
            return "Invalid FPC wire format"
        case .unsupportedVersion(let version):
            return "Unsupported FPC protocol version: \(version)"
        case .unexpectedMessage(let id):
            return "Unexpected FPC message: \(id)"
        case .timeout:
            return "FPC operation timed out"
        case .tooManyDescriptors(let count):
            return "Too many file descriptors (\(count)); maximum is 254 per message"
        }
    }
}
