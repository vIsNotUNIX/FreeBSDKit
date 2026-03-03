/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit
import Dispatch

/// Shared queue for blocking sendfile operations.
private let sendfileBlockingQueue = DispatchQueue(
    label: "com.freebsdkit.sendfile.blocking",
    qos: .userInitiated,
    attributes: .concurrent
)

// MARK: - OpaqueDescriptorRef + Sendfile

public extension OpaqueDescriptorRef {

    /// Send a file to a socket using zero-copy transfer.
    ///
    /// `sendfile(2)` transmits file data directly from the kernel's buffer cache
    /// to the socket without copying through user space.
    ///
    /// - Parameters:
    ///   - socket: Socket descriptor to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Result containing bytes sent and completion status
    /// - Throws: `BSDError` on failure, `POSIXError(.EBADF)` if descriptor is invalid
    func sendTo(
        _ socket: OpaqueDescriptorRef,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) throws -> SendfileResult {
        guard let fileFD = self.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        guard let socketFD = socket.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        return try sendfile(from: fileFD, to: socketFD, offset: offset, count: count, flags: flags)
    }

    /// Send a file to a socket with headers and/or trailers.
    ///
    /// - Parameters:
    ///   - socket: Socket descriptor to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - headersTrailers: Headers and trailers to send with the file
    ///   - flags: Sendfile behavior flags
    /// - Returns: Result containing bytes sent and completion status
    /// - Throws: `BSDError` on failure, `POSIXError(.EBADF)` if descriptor is invalid
    func sendTo(
        _ socket: OpaqueDescriptorRef,
        offset: off_t = 0,
        count: Int? = nil,
        headersTrailers: borrowing SendfileHeadersTrailers,
        flags: SendfileFlags = []
    ) throws -> SendfileResult {
        guard let fileFD = self.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        guard let socketFD = socket.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        return try sendfile(
            from: fileFD,
            to: socketFD,
            offset: offset,
            count: count,
            headersTrailers: headersTrailers,
            flags: flags
        )
    }
}

// MARK: - FileDescriptor + Sendfile

public extension FileDescriptor where Self: ~Copyable {

    /// Send this file's contents to a socket using zero-copy transfer.
    ///
    /// `sendfile(2)` transmits file data directly from the kernel's buffer cache
    /// to the socket without copying through user space. This is significantly
    /// more efficient than read()/write() loops for serving static files.
    ///
    /// - Parameters:
    ///   - socket: Stream socket to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Result containing bytes sent and completion status
    /// - Throws: `BSDError` on failure
    func sendTo(
        _ socket: borrowing some SocketDescriptor & ~Copyable,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) throws -> SendfileResult {
        try self.unsafe { fileFD in
            try socket.unsafe { socketFD in
                try sendfile(from: fileFD, to: socketFD, offset: offset, count: count, flags: flags)
            }
        }
    }

    /// Send this file's contents to a socket with headers and/or trailers.
    ///
    /// This variant allows prepending headers (e.g., HTTP response headers)
    /// and appending trailers (e.g., chunked encoding terminator) to the file
    /// data, all sent in a single efficient operation.
    ///
    /// - Parameters:
    ///   - socket: Stream socket to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - headersTrailers: Headers and trailers to send with the file
    ///   - flags: Sendfile behavior flags
    /// - Returns: Result containing bytes sent and completion status
    /// - Throws: `BSDError` on failure
    func sendTo(
        _ socket: borrowing some SocketDescriptor & ~Copyable,
        offset: off_t = 0,
        count: Int? = nil,
        headersTrailers: borrowing SendfileHeadersTrailers,
        flags: SendfileFlags = []
    ) throws -> SendfileResult {
        try self.unsafe { fileFD in
            try socket.unsafe { socketFD in
                try sendfile(
                    from: fileFD,
                    to: socketFD,
                    offset: offset,
                    count: count,
                    headersTrailers: headersTrailers,
                    flags: flags
                )
            }
        }
    }
}

// MARK: - SocketDescriptor + Sendfile

public extension SocketDescriptor where Self: ~Copyable {

    /// Receive a file from another descriptor using zero-copy transfer.
    ///
    /// This is a convenience method that calls sendfile with this socket
    /// as the destination.
    ///
    /// - Parameters:
    ///   - file: File descriptor to send from
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Result containing bytes sent and completion status
    /// - Throws: `BSDError` on failure
    func receiveFile(
        from file: borrowing some FileDescriptor & ~Copyable,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) throws -> SendfileResult {
        try file.unsafe { fileFD in
            try self.unsafe { socketFD in
                try sendfile(from: fileFD, to: socketFD, offset: offset, count: count, flags: flags)
            }
        }
    }
}

// MARK: - Async Sendfile

/// Asynchronously send a file to a socket using zero-copy transfer.
///
/// This function handles partial sends automatically, retrying until all
/// data is sent or an error occurs. The blocking I/O is offloaded to a
/// background dispatch queue to avoid blocking the cooperative thread pool.
///
/// - Parameters:
///   - fileFD: File descriptor of the file to send
///   - socketFD: Stream socket descriptor to send to
///   - offset: Starting offset in the file (0 for beginning)
///   - count: Number of bytes to send (nil for entire file from offset)
///   - flags: Sendfile behavior flags
/// - Returns: Total bytes sent
/// - Throws: `BSDError` on failure, `CancellationError` if task is cancelled
public func sendfileAsync(
    from fileFD: Int32,
    to socketFD: Int32,
    offset: off_t = 0,
    count: Int? = nil,
    flags: SendfileFlags = []
) async throws -> Int {
    // Duplicate descriptors so the blocking work has owned copies
    let ownedFileFD = Glibc.fcntl(fileFD, F_DUPFD_CLOEXEC, 0)
    guard ownedFileFD != -1 else {
        throw BSDError.fromErrno(errno)
    }

    let ownedSocketFD = Glibc.fcntl(socketFD, F_DUPFD_CLOEXEC, 0)
    guard ownedSocketFD != -1 else {
        Glibc.close(ownedFileFD)
        throw BSDError.fromErrno(errno)
    }

    return try await withCheckedThrowingContinuation { continuation in
        sendfileBlockingQueue.async {
            defer {
                Glibc.close(ownedFileFD)
                Glibc.close(ownedSocketFD)
            }

            var totalSent: Int = 0
            var currentOffset = offset
            let nbytes = count ?? 0  // 0 means send until EOF

            while true {
                var bytesSent: off_t = 0

                let result = Glibc.sendfile(
                    ownedFileFD,
                    ownedSocketFD,
                    currentOffset,
                    nbytes == 0 ? 0 : nbytes - totalSent,
                    nil,
                    &bytesSent,
                    flags.rawValue
                )

                totalSent += Int(bytesSent)
                currentOffset += bytesSent

                if result == 0 {
                    // Success - all data sent
                    do {
                        try Task.checkCancellation()
                        continuation.resume(returning: totalSent)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                let err = errno

                // Handle partial sends (non-blocking socket or signal interrupt)
                if err == EAGAIN || err == EINTR {
                    // Check cancellation between retries
                    do {
                        try Task.checkCancellation()
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }

                    // If we have a specific count and sent it all, we're done
                    if nbytes > 0 && totalSent >= nbytes {
                        continuation.resume(returning: totalSent)
                        return
                    }

                    // Continue sending
                    continue
                }

                // Real error
                continuation.resume(throwing: BSDError.fromErrno(err))
                return
            }
        }
    }
}

// MARK: - OpaqueDescriptorRef + Async Sendfile

public extension OpaqueDescriptorRef {

    /// Asynchronously send a file to a socket using zero-copy transfer.
    ///
    /// This method handles partial sends automatically, retrying until all
    /// data is sent or an error occurs.
    ///
    /// - Parameters:
    ///   - socket: Socket descriptor to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Total bytes sent
    /// - Throws: `BSDError` on failure, `CancellationError` if task is cancelled
    func sendToAsync(
        _ socket: OpaqueDescriptorRef,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) async throws -> Int {
        guard let fileFD = self.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        guard let socketFD = socket.toBSDValue() else {
            throw POSIXError(.EBADF)
        }
        return try await sendfileAsync(
            from: fileFD,
            to: socketFD,
            offset: offset,
            count: count,
            flags: flags
        )
    }
}

// MARK: - FileDescriptor + Async Sendfile

public extension FileDescriptor where Self: ~Copyable {

    /// Asynchronously send this file's contents to a socket.
    ///
    /// This method handles partial sends automatically, retrying until all
    /// data is sent or an error occurs. The blocking I/O is offloaded to a
    /// background dispatch queue.
    ///
    /// - Parameters:
    ///   - socket: Stream socket to send to
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Total bytes sent
    /// - Throws: `BSDError` on failure, `CancellationError` if task is cancelled
    func sendToAsync(
        _ socket: borrowing some SocketDescriptor & ~Copyable,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) async throws -> Int {
        // Extract raw fds synchronously, then call async function
        let fileFD: Int32 = self.unsafe { $0 }
        let socketFD: Int32 = socket.unsafe { $0 }
        return try await sendfileAsync(
            from: fileFD,
            to: socketFD,
            offset: offset,
            count: count,
            flags: flags
        )
    }
}

// MARK: - SocketDescriptor + Async Sendfile

public extension SocketDescriptor where Self: ~Copyable {

    /// Asynchronously receive a file from another descriptor.
    ///
    /// This method handles partial sends automatically, retrying until all
    /// data is sent or an error occurs.
    ///
    /// - Parameters:
    ///   - file: File descriptor to send from
    ///   - offset: Starting offset in the file (0 for beginning)
    ///   - count: Number of bytes to send (nil for entire file from offset)
    ///   - flags: Sendfile behavior flags
    /// - Returns: Total bytes sent
    /// - Throws: `BSDError` on failure, `CancellationError` if task is cancelled
    func receiveFileAsync(
        from file: borrowing some FileDescriptor & ~Copyable,
        offset: off_t = 0,
        count: Int? = nil,
        flags: SendfileFlags = []
    ) async throws -> Int {
        // Extract raw fds synchronously, then call async function
        let fileFD: Int32 = file.unsafe { $0 }
        let socketFD: Int32 = self.unsafe { $0 }
        return try await sendfileAsync(
            from: fileFD,
            to: socketFD,
            offset: offset,
            count: count,
            flags: flags
        )
    }
}
