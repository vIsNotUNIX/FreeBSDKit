/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import COpenCrypto
import Glibc

/// A hash session for computing digests or HMACs.
///
/// Hash sessions are created via `OpenCrypto.hash()` or `OpenCrypto.hmac()`
/// and provide hardware-accelerated hashing when available.
///
/// ## Example
/// ```swift
/// let crypto = try OpenCrypto()
///
/// // Simple hashing
/// let hasher = try crypto.hash(.sha256)
/// let digest = try hasher.hash(data)
///
/// // HMAC
/// let hmac = try crypto.hmac(.sha256, key: key)
/// let mac = try hmac.authenticate(message)
/// ```
public struct HashSession: ~Copyable {
    private var fd: Int32
    private var sessionId: UInt32
    private let algorithm: HashAlgorithm
    private let isHMAC: Bool

    init(fd: Int32, algorithm: HashAlgorithm, key: [UInt8]?) throws {
        let sessId = try Self.createSession(fd: fd, algorithm: algorithm, key: key)

        self.fd = fd
        self.algorithm = algorithm
        self.isHMAC = key != nil
        self.sessionId = sessId
    }

    private static func createSession(fd: Int32, algorithm: HashAlgorithm, key: [UInt8]?) throws -> UInt32 {
        var sessId: UInt32 = 0
        let result: Int32

        if let key = key {
            result = key.withUnsafeBytes { keyPtr in
                copencrypto_hash_session(
                    fd,
                    algorithm.hmacAlgorithm,
                    keyPtr.baseAddress,
                    UInt32(key.count),
                    &sessId
                )
            }
        } else {
            result = copencrypto_hash_session(
                fd,
                algorithm.kernelAlgorithm,
                nil,
                0,
                &sessId
            )
        }

        if result != 0 {
            throw CryptoError.sessionFailed(errno: errno)
        }

        return sessId
    }

    deinit {
        copencrypto_destroy_session(fd, sessionId)
    }

    /// Computes the hash/HMAC of data.
    ///
    /// - Parameter data: The data to hash.
    /// - Returns: The digest or MAC.
    /// - Throws: `CryptoError` if the operation fails.
    public func hash(_ data: [UInt8]) throws -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: algorithm.digestSize)

        let result = data.withUnsafeBytes { dataPtr in
            digest.withUnsafeMutableBytes { digestPtr in
                copencrypto_hash(
                    fd,
                    sessionId,
                    dataPtr.baseAddress,
                    UInt32(data.count),
                    digestPtr.baseAddress
                )
            }
        }

        guard result == 0 else {
            throw CryptoError.operationFailed(errno: errno)
        }

        return digest
    }

    /// Computes the HMAC of a message.
    ///
    /// This is an alias for `hash()` when used with an HMAC session.
    ///
    /// - Parameter message: The message to authenticate.
    /// - Returns: The authentication tag.
    /// - Throws: `CryptoError` if the operation fails.
    public func authenticate(_ message: [UInt8]) throws -> [UInt8] {
        return try hash(message)
    }

    /// Verifies an HMAC.
    ///
    /// - Parameters:
    ///   - message: The message to verify.
    ///   - tag: The expected MAC.
    /// - Returns: `true` if the MAC is valid.
    /// - Throws: `CryptoError` if the operation fails.
    public func verify(_ message: [UInt8], tag: [UInt8]) throws -> Bool {
        let computed = try hash(message)
        // Constant-time comparison
        guard computed.count == tag.count else { return false }
        var result: UInt8 = 0
        for i in 0..<computed.count {
            result |= computed[i] ^ tag[i]
        }
        return result == 0
    }

    /// The hash algorithm being used.
    public var hashAlgorithm: HashAlgorithm {
        return algorithm
    }

    /// The digest size in bytes.
    public var digestSize: Int {
        return algorithm.digestSize
    }
}
