/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import COpenCrypto
import Glibc

/// A cipher session for symmetric encryption/decryption.
///
/// Cipher sessions are created via `OpenCrypto.cipher()` and provide
/// hardware-accelerated encryption when available.
///
/// ## Example
/// ```swift
/// let crypto = try OpenCrypto()
/// let cipher = try crypto.cipher(.aes256CBC, key: key)
///
/// // Encrypt
/// let ciphertext = try cipher.encrypt(plaintext, iv: iv)
///
/// // Decrypt
/// let decrypted = try cipher.decrypt(ciphertext, iv: iv)
/// ```
public struct CipherSession: ~Copyable {
    private var fd: Int32
    private var sessionId: UInt32
    private let algorithm: CipherAlgorithm

    init(fd: Int32, algorithm: CipherAlgorithm, key: [UInt8]) throws {
        // All validation and session creation before field init
        let sessId = try Self.createSession(fd: fd, algorithm: algorithm, key: key)

        self.fd = fd
        self.algorithm = algorithm
        self.sessionId = sessId
    }

    private static func createSession(fd: Int32, algorithm: CipherAlgorithm, key: [UInt8]) throws -> UInt32 {
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

    /// Encrypts data.
    ///
    /// - Parameters:
    ///   - plaintext: The data to encrypt.
    ///   - iv: The initialization vector.
    /// - Returns: The encrypted data.
    /// - Throws: `CryptoError` if encryption fails.
    public func encrypt(_ plaintext: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        try process(plaintext, iv: iv, operation: COPENCRYPTO_ENCRYPT)
    }

    /// Decrypts data.
    ///
    /// - Parameters:
    ///   - ciphertext: The data to decrypt.
    ///   - iv: The initialization vector used during encryption.
    /// - Returns: The decrypted data.
    /// - Throws: `CryptoError` if decryption fails.
    public func decrypt(_ ciphertext: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        try process(ciphertext, iv: iv, operation: COPENCRYPTO_DECRYPT)
    }

    /// Encrypts data in place.
    ///
    /// - Parameters:
    ///   - data: The data to encrypt (modified in place).
    ///   - iv: The initialization vector.
    /// - Throws: `CryptoError` if encryption fails.
    public func encryptInPlace(_ data: inout [UInt8], iv: [UInt8]) throws {
        try processInPlace(&data, iv: iv, operation: COPENCRYPTO_ENCRYPT)
    }

    /// Decrypts data in place.
    ///
    /// - Parameters:
    ///   - data: The data to decrypt (modified in place).
    ///   - iv: The initialization vector used during encryption.
    /// - Throws: `CryptoError` if decryption fails.
    public func decryptInPlace(_ data: inout [UInt8], iv: [UInt8]) throws {
        try processInPlace(&data, iv: iv, operation: COPENCRYPTO_DECRYPT)
    }

    private func process(_ input: [UInt8], iv: [UInt8], operation: Int32) throws -> [UInt8] {
        // Validate IV size
        guard iv.count == algorithm.ivSize else {
            throw CryptoError.invalidIVSize(expected: algorithm.ivSize, got: iv.count)
        }

        // For CBC mode, input must be multiple of block size
        switch algorithm {
        case .aes128CBC, .aes192CBC, .aes256CBC:
            guard input.count % algorithm.blockSize == 0 else {
                throw CryptoError.invalidInputSize(
                    message: "Input must be multiple of \(algorithm.blockSize) bytes for CBC mode"
                )
            }
        default:
            break
        }

        var output = [UInt8](repeating: 0, count: input.count)

        let result = input.withUnsafeBytes { inputPtr in
            output.withUnsafeMutableBytes { outputPtr in
                iv.withUnsafeBytes { ivPtr in
                    copencrypto_cipher(
                        fd,
                        sessionId,
                        operation,
                        ivPtr.baseAddress,
                        inputPtr.baseAddress,
                        outputPtr.baseAddress,
                        UInt32(input.count)
                    )
                }
            }
        }

        guard result == 0 else {
            throw CryptoError.operationFailed(errno: errno)
        }

        return output
    }

    private func processInPlace(_ data: inout [UInt8], iv: [UInt8], operation: Int32) throws {
        guard iv.count == algorithm.ivSize else {
            throw CryptoError.invalidIVSize(expected: algorithm.ivSize, got: iv.count)
        }

        switch algorithm {
        case .aes128CBC, .aes192CBC, .aes256CBC:
            guard data.count % algorithm.blockSize == 0 else {
                throw CryptoError.invalidInputSize(
                    message: "Input must be multiple of \(algorithm.blockSize) bytes for CBC mode"
                )
            }
        default:
            break
        }

        let result = data.withUnsafeMutableBytes { dataPtr in
            iv.withUnsafeBytes { ivPtr in
                copencrypto_cipher(
                    fd,
                    sessionId,
                    operation,
                    ivPtr.baseAddress,
                    dataPtr.baseAddress,
                    dataPtr.baseAddress,
                    UInt32(dataPtr.count)
                )
            }
        }

        guard result == 0 else {
            throw CryptoError.operationFailed(errno: errno)
        }
    }

    /// The cipher algorithm being used.
    public var cipherAlgorithm: CipherAlgorithm {
        return algorithm
    }
}
