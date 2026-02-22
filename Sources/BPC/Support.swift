/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Capabilities

// MARK: - ConnectionState

/// Tracks the connection state of a BPC endpoint or listener.
///
/// - `idle`: Created but not yet started
/// - `running`: Active and processing messages/connections
/// - `stopped`: Shut down and no longer usable
public enum ConnectionState: Sendable {
    /// Created but not yet started. Call `start()` to transition to `running`.
    case idle
    /// Active and processing messages or connections.
    case running
    /// Shut down and no longer usable. The connection cannot be restarted.
    case stopped
}

// Internal alias for backward compatibility
typealias LifecycleState = ConnectionState

// MARK: - SocketHolder

/// Wraps a `~Copyable` ``SocketCapability`` for use in reference-typed containers.
///
/// All socket access is serialised through an `NSLock` so that the holder can be
/// shared between an actor and its off-actor `DispatchQueue` I/O work items.
final class SocketHolder: @unchecked Sendable {
    private var socket: SocketCapability?
    private let lock = NSLock()

    init(socket: consuming SocketCapability) {
        self.socket = consume socket
    }

    deinit {
        close()
    }

    /// Calls `body` with a borrowed reference to the socket, or returns `nil` if
    /// the socket has already been closed. Use this when the caller needs to
    /// distinguish a closed socket from other errors (e.g. ``BSDListener/accept()``).
    func withSocket<R>(_ body: (borrowing SocketCapability) throws -> R) rethrows -> R? where R: ~Copyable {
        lock.lock()
        defer { lock.unlock() }
        guard socket != nil else { return nil }
        return try body(socket!)
    }

    /// Calls `body` with a borrowed reference to the socket, or throws
    /// ``BPCError/disconnected`` if the socket has already been closed.
    func withSocketOrThrow<R>(_ body: (borrowing SocketCapability) throws -> R) throws -> R where R: ~Copyable {
        lock.lock()
        defer { lock.unlock() }
        guard socket != nil else { throw BPCError.disconnected }
        return try body(socket!)
    }

    /// Closes the underlying socket and releases it.
    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard socket != nil else { return }
        // Close the FD directly - the socket's deinit will attempt to close again
        // but that's safe (just returns EBADF)
        socket!.unsafe { fd in _ = Glibc.close(fd) }
        self.socket = nil
    }
}