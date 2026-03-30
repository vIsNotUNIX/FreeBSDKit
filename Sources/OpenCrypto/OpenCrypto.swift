/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import COpenCrypto
import Glibc

/// Swift interface to FreeBSD's OpenCrypto framework.
///
/// OpenCrypto provides hardware-accelerated cryptographic operations
/// via /dev/crypto. When hardware acceleration is available (AES-NI,
/// SHA extensions), operations are significantly faster than software
/// implementations.
///
/// ## Example
/// ```swift
/// // Create a crypto context
/// let crypto = try OpenCrypto()
///
/// // AES-256-CBC encryption
/// let cipher = try crypto.cipher(.aes256CBC, key: key)
/// let ciphertext = try cipher.encrypt(plaintext, iv: iv)
/// let decrypted = try cipher.decrypt(ciphertext, iv: iv)
///
/// // SHA-256 hashing
/// let hasher = try crypto.hash(.sha256)
/// let digest = try hasher.hash(data)
///
/// // HMAC-SHA256
/// let hmac = try crypto.hmac(.sha256, key: key)
/// let mac = try hmac.authenticate(message)
///
/// // AES-GCM authenticated encryption
/// let aead = try crypto.aead(.aesGCM, key: key)
/// let (ciphertext, tag) = try aead.seal(plaintext, iv: nonce, aad: header)
/// let plaintext = try aead.open(ciphertext, iv: nonce, aad: header, tag: tag)
/// ```
public struct OpenCrypto: ~Copyable {
    private var fd: Int32

    /// Opens the /dev/crypto device.
    ///
    /// - Throws: `CryptoError.openFailed` if the device cannot be opened.
    public init() throws {
        fd = copencrypto_open()
        guard fd >= 0 else {
            throw CryptoError.openFailed(errno: errno)
        }
    }

    deinit {
        if fd >= 0 {
            copencrypto_close(fd)
        }
    }

    /// Creates a cipher session.
    ///
    /// - Parameters:
    ///   - algorithm: The cipher algorithm to use.
    ///   - key: The encryption key.
    /// - Returns: A cipher session for encryption/decryption.
    /// - Throws: `CryptoError` if session creation fails.
    public func cipher(_ algorithm: CipherAlgorithm, key: [UInt8]) throws -> CipherSession {
        return try CipherSession(fd: fd, algorithm: algorithm, key: key)
    }

    /// Creates a hash session.
    ///
    /// - Parameter algorithm: The hash algorithm to use.
    /// - Returns: A hash session for computing digests.
    /// - Throws: `CryptoError` if session creation fails.
    public func hash(_ algorithm: HashAlgorithm) throws -> HashSession {
        return try HashSession(fd: fd, algorithm: algorithm, key: nil)
    }

    /// Creates an HMAC session.
    ///
    /// - Parameters:
    ///   - algorithm: The hash algorithm to use for HMAC.
    ///   - key: The HMAC key.
    /// - Returns: An HMAC session for computing MACs.
    /// - Throws: `CryptoError` if session creation fails.
    public func hmac(_ algorithm: HashAlgorithm, key: [UInt8]) throws -> HashSession {
        return try HashSession(fd: fd, algorithm: algorithm, key: key)
    }

    /// Creates an AEAD session.
    ///
    /// - Parameters:
    ///   - algorithm: The AEAD algorithm to use.
    ///   - key: The encryption key.
    /// - Returns: An AEAD session for authenticated encryption.
    /// - Throws: `CryptoError` if session creation fails.
    public func aead(_ algorithm: AEADAlgorithm, key: [UInt8]) throws -> AEADSession {
        return try AEADSession(fd: fd, algorithm: algorithm, key: key)
    }
}
