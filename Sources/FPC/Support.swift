/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import Capabilities

// MARK: - ConnectionState

/// Tracks the connection state of a FPC endpoint or listener.
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
/// Allows concurrent I/O operations on the socket. The `closed` flag is
/// checked atomically, and close() calls shutdown() to interrupt blocking I/O.
/// I/O operations do NOT hold a lock during execution, allowing concurrent recv/send.
final class SocketHolder: @unchecked Sendable {
    private var socket: SocketCapability?
    private var fd: Int32 = -1
    @Atomic private var closed: Bool = false
    private let closeLock = NSLock()  // Only used for close() synchronization

    init(socket: consuming SocketCapability) {
        // Extract the FD before storing the socket
        socket.unsafe { fd in
            self.fd = fd
        }
        self.socket = consume socket
    }

    deinit {
        close()
    }

    /// Calls `body` with a borrowed reference to the socket, or returns `nil` if
    /// the socket has already been closed. Use this when the caller needs to
    /// distinguish a closed socket from other errors (e.g. ``FPCListener/accept()``).
    ///
    /// No lock is held during `body`, allowing concurrent I/O operations.
    func withSocket<R>(_ body: (borrowing SocketCapability) throws -> R) rethrows -> R? where R: ~Copyable {
        guard !closed else { return nil }
        guard socket != nil else { return nil }
        return try body(socket!)
    }

    /// Calls `body` with a borrowed reference to the socket, or throws
    /// ``FPCError/disconnected`` if the socket has already been closed.
    ///
    /// No lock is held during `body`, allowing concurrent I/O operations.
    func withSocketOrThrow<R>(_ body: (borrowing SocketCapability) throws -> R) throws -> R where R: ~Copyable {
        guard !closed else { throw FPCError.disconnected }
        guard socket != nil else { throw FPCError.disconnected }
        return try body(socket!)
    }

    /// Closes the underlying socket and releases it.
    ///
    /// First shuts down the socket to unblock any pending I/O operations,
    /// then closes the file descriptor.
    func close() {
        closeLock.lock()
        defer { closeLock.unlock() }

        guard !closed else { return }

        // Set closed flag first to prevent new I/O
        closed = true

        // Shutdown the socket to unblock waiting recv/send
        // This causes recv to return 0 and send to fail with EPIPE
        if fd >= 0 {
            _ = Glibc.shutdown(fd, Int32(SHUT_RDWR.rawValue))
        }

        // Close the socket
        self.socket = nil
        self.fd = -1
    }
}

// MARK: - Atomic Property Wrapper

@propertyWrapper
struct Atomic<Value> {
    private var value: Value
    private let lock = NSLock()

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
}