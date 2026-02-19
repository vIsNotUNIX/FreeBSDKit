/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Capabilities

// MARK: - LifecycleState

/// Tracks the three-phase lifecycle shared by ``BSDEndpoint`` and ``BSDListener``.
enum LifecycleState { case idle, running, stopped }

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
        socket!.unsafe { fd in _ = Glibc.close(fd) }
        self.socket = nil
    }
}
