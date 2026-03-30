/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

// Forward declare getrandom from libc
@_silgen_name("getrandom")
private func c_getrandom(
    _ buf: UnsafeMutableRawPointer,
    _ buflen: Int,
    _ flags: UInt32
) -> Int

/// Swift interface to FreeBSD's getrandom(2) system call.
///
/// Provides cryptographically secure random bytes from the kernel's
/// random number generator. This is the recommended way to obtain
/// random data for cryptographic purposes.
///
/// ## Example
/// ```swift
/// // Get 32 random bytes
/// let key = try BSDRandom.bytes(32)
///
/// // Fill a buffer
/// var buffer = [UInt8](repeating: 0, count: 64)
/// try BSDRandom.fill(&buffer)
///
/// // Get a random value of any type
/// let nonce: UInt64 = try BSDRandom.value()
///
/// // Non-blocking (fails if entropy unavailable)
/// let bytes = try BSDRandom.bytes(16, flags: .nonBlocking)
/// ```
public enum BSDRandom {

    // MARK: - Flags

    /// Flags for getrandom(2).
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Return immediately if no random bytes are available.
        /// Without this flag, the call blocks until bytes are available.
        public static let nonBlocking = Flags(rawValue: 0x1)  // GRND_NONBLOCK

        /// Use /dev/random instead of /dev/urandom.
        /// This may block longer but provides "true" random bytes.
        public static let random = Flags(rawValue: 0x2)  // GRND_RANDOM

        /// Allow returning bytes even if the random device is not
        /// yet seeded. Use with caution - bytes may be predictable.
        public static let insecure = Flags(rawValue: 0x4)  // GRND_INSECURE
    }

    // MARK: - Error

    /// Errors that can occur during random byte generation.
    public enum Error: Swift.Error, Equatable {
        /// Would block and GRND_NONBLOCK was specified.
        case wouldBlock
        /// Interrupted by a signal.
        case interrupted
        /// Invalid flags or buffer.
        case invalidArgument
        /// Other system error.
        case systemError(Int32)

        init(errno: Int32) {
            switch errno {
            case EAGAIN:
                self = .wouldBlock
            case EINTR:
                self = .interrupted
            case EINVAL, EFAULT:
                self = .invalidArgument
            default:
                self = .systemError(errno)
            }
        }
    }

    // MARK: - Public API

    /// Generates cryptographically secure random bytes.
    ///
    /// - Parameters:
    ///   - count: Number of random bytes to generate.
    ///   - flags: Optional flags (default: none, blocking).
    /// - Returns: Array of random bytes.
    /// - Throws: `BSDRandom.Error` if generation fails.
    public static func bytes(_ count: Int, flags: Flags = []) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        try fill(&buffer, flags: flags)
        return buffer
    }

    /// Fills a buffer with cryptographically secure random bytes.
    ///
    /// - Parameters:
    ///   - buffer: Buffer to fill with random bytes.
    ///   - flags: Optional flags (default: none, blocking).
    /// - Throws: `BSDRandom.Error` if generation fails.
    public static func fill(_ buffer: inout [UInt8], flags: Flags = []) throws {
        try buffer.withUnsafeMutableBytes { ptr in
            try fill(ptr.baseAddress!, count: ptr.count, flags: flags)
        }
    }

    /// Fills a raw buffer with cryptographically secure random bytes.
    ///
    /// - Parameters:
    ///   - pointer: Pointer to buffer to fill.
    ///   - count: Number of bytes to generate.
    ///   - flags: Optional flags (default: none, blocking).
    /// - Throws: `BSDRandom.Error` if generation fails.
    public static func fill(
        _ pointer: UnsafeMutableRawPointer,
        count: Int,
        flags: Flags = []
    ) throws {
        var remaining = count
        var current = pointer

        while remaining > 0 {
            let result = c_getrandom(current, remaining, flags.rawValue)

            if result < 0 {
                let err = errno
                // Retry on EINTR unless non-blocking
                if err == EINTR && !flags.contains(.nonBlocking) {
                    continue
                }
                throw Error(errno: err)
            }

            remaining -= result
            current = current.advanced(by: result)
        }
    }

    /// Generates a random value of the specified type.
    ///
    /// - Parameter flags: Optional flags (default: none, blocking).
    /// - Returns: A random value of type T.
    /// - Throws: `BSDRandom.Error` if generation fails.
    ///
    /// ## Example
    /// ```swift
    /// let id: UInt64 = try BSDRandom.value()
    /// let nonce: UInt32 = try BSDRandom.value()
    /// ```
    public static func value<T>(flags: Flags = []) throws -> T {
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }

        try fill(ptr, count: size, flags: flags)
        return ptr.load(as: T.self)
    }

}
