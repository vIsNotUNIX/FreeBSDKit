/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import COpenCrypto
import Glibc

/// An AEAD session for authenticated encryption.
///
/// AEAD (Authenticated Encryption with Associated Data) provides both
/// confidentiality and integrity protection. It's the recommended mode
/// for most encryption use cases.
///
/// ## Example
/// ```swift
/// let crypto = try OpenCrypto()
/// let aead = try crypto.aead(.aes256GCM, key: key)
///
/// // Encrypt and authenticate
/// let (ciphertext, tag) = try aead.seal(plaintext, nonce: nonce, aad: header)
///
/// // Decrypt and verify
/// let plaintext = try aead.open(ciphertext, nonce: nonce, aad: header, tag: tag)
/// ```
public struct AEADSession: ~Copyable {
    private var fd: Int32
    private var sessionId: UInt32
    private let algorithm: AEADAlgorithm

    init(fd: Int32, algorithm: AEADAlgorithm, key: [UInt8]) throws {
        let sessId = try Self.createSession(fd: fd, algorithm: algorithm, key: key)

        self.fd = fd
        self.algorithm = algorithm
        self.sessionId = sessId
    }

    private static func createSession(fd: Int32, algorithm: AEADAlgorithm, key: [UInt8]) throws -> UInt32 {
        if key.count != algorithm.keySize {
            throw CryptoError.invalidKeySize(expected: algorithm.keySize, got: key.count)
        }

        var sessId: UInt32 = 0
        let result = key.withUnsafeBytes { keyPtr in
            copencrypto_cipher_session(
                fd,
                algorithm.kernelAlgorithm,
                keyPtr.baseAddress,
                UInt32(key.count),
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

    /// Encrypts and authenticates data.
    ///
    /// - Parameters:
    ///   - plaintext: The data to encrypt.
    ///   - nonce: The nonce/IV (must be unique for each encryption with same key).
    ///   - aad: Additional authenticated data (optional, not encrypted but authenticated).
    /// - Returns: A tuple of (ciphertext, authentication tag).
    /// - Throws: `CryptoError` if encryption fails.
    public func seal(
        _ plaintext: [UInt8],
        nonce: [UInt8],
        aad: [UInt8] = []
    ) throws -> (ciphertext: [UInt8], tag: [UInt8]) {
        guard nonce.count == algorithm.nonceSize else {
            throw CryptoError.invalidIVSize(expected: algorithm.nonceSize, got: nonce.count)
        }

        var ciphertext = [UInt8](repeating: 0, count: plaintext.count)
        var tag = [UInt8](repeating: 0, count: algorithm.tagSize)

        let result = plaintext.withUnsafeBytes { ptPtr in
            ciphertext.withUnsafeMutableBytes { ctPtr in
                tag.withUnsafeMutableBytes { tagPtr in
                    nonce.withUnsafeBytes { noncePtr in
                        aad.withUnsafeBytes { aadPtr in
                            copencrypto_aead(
                                fd,
                                sessionId,
                                COPENCRYPTO_ENCRYPT,
                                noncePtr.baseAddress,
                                UInt32(nonce.count),
                                aadPtr.baseAddress,
                                UInt32(aad.count),
                                ptPtr.baseAddress,
                                ctPtr.baseAddress,
                                UInt32(plaintext.count),
                                tagPtr.baseAddress,
                                UInt32(algorithm.tagSize)
                            )
                        }
                    }
                }
            }
        }

        guard result == 0 else {
            throw CryptoError.operationFailed(errno: errno)
        }

        return (ciphertext, tag)
    }

    /// Decrypts and verifies data.
    ///
    /// - Parameters:
    ///   - ciphertext: The data to decrypt.
    ///   - nonce: The nonce/IV used during encryption.
    ///   - aad: Additional authenticated data (must match what was used during encryption).
    ///   - tag: The authentication tag from encryption.
    /// - Returns: The decrypted plaintext.
    /// - Throws: `CryptoError.authenticationFailed` if the tag doesn't verify.
    public func open(
        _ ciphertext: [UInt8],
        nonce: [UInt8],
        aad: [UInt8] = [],
        tag: [UInt8]
    ) throws -> [UInt8] {
        guard nonce.count == algorithm.nonceSize else {
            throw CryptoError.invalidIVSize(expected: algorithm.nonceSize, got: nonce.count)
        }

        guard tag.count == algorithm.tagSize else {
            throw CryptoError.invalidInputSize(
                message: "Tag must be \(algorithm.tagSize) bytes"
            )
        }

        var plaintext = [UInt8](repeating: 0, count: ciphertext.count)
        var tagCopy = tag  // Need mutable copy for the ioctl

        let result = ciphertext.withUnsafeBytes { ctPtr in
            plaintext.withUnsafeMutableBytes { ptPtr in
                tagCopy.withUnsafeMutableBytes { tagPtr in
                    nonce.withUnsafeBytes { noncePtr in
                        aad.withUnsafeBytes { aadPtr in
                            copencrypto_aead(
                                fd,
                                sessionId,
                                COPENCRYPTO_DECRYPT,
                                noncePtr.baseAddress,
                                UInt32(nonce.count),
                                aadPtr.baseAddress,
                                UInt32(aad.count),
                                ctPtr.baseAddress,
                                ptPtr.baseAddress,
                                UInt32(ciphertext.count),
                                tagPtr.baseAddress,
                                UInt32(tag.count)
                            )
                        }
                    }
                }
            }
        }

        if result != 0 {
            let err = errno
            // EBADMSG typically indicates authentication failure
            if err == EBADMSG {
                throw CryptoError.authenticationFailed
            }
            throw CryptoError.operationFailed(errno: err)
        }

        return plaintext
    }

    /// Encrypts data with combined ciphertext and tag.
    ///
    /// - Parameters:
    ///   - plaintext: The data to encrypt.
    ///   - nonce: The nonce/IV.
    ///   - aad: Additional authenticated data.
    /// - Returns: Combined ciphertext || tag.
    /// - Throws: `CryptoError` if encryption fails.
    public func sealCombined(
        _ plaintext: [UInt8],
        nonce: [UInt8],
        aad: [UInt8] = []
    ) throws -> [UInt8] {
        let (ciphertext, tag) = try seal(plaintext, nonce: nonce, aad: aad)
        return ciphertext + tag
    }

    /// Decrypts combined ciphertext || tag.
    ///
    /// - Parameters:
    ///   - combined: The ciphertext with appended tag.
    ///   - nonce: The nonce/IV.
    ///   - aad: Additional authenticated data.
    /// - Returns: The decrypted plaintext.
    /// - Throws: `CryptoError` if decryption or verification fails.
    public func openCombined(
        _ combined: [UInt8],
        nonce: [UInt8],
        aad: [UInt8] = []
    ) throws -> [UInt8] {
        guard combined.count >= algorithm.tagSize else {
            throw CryptoError.invalidInputSize(
                message: "Combined data too short (need at least \(algorithm.tagSize) bytes for tag)"
            )
        }

        let ctLen = combined.count - algorithm.tagSize
        let ciphertext = Array(combined[0..<ctLen])
        let tag = Array(combined[ctLen...])

        return try open(ciphertext, nonce: nonce, aad: aad, tag: tag)
    }

    /// The AEAD algorithm being used.
    public var aeadAlgorithm: AEADAlgorithm {
        return algorithm
    }
}
