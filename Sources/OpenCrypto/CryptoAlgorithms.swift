/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import COpenCrypto

/// Cipher algorithms supported by OpenCrypto.
public enum CipherAlgorithm: UInt32, Sendable {
    /// AES-128 in CBC mode (128-bit key).
    case aes128CBC = 11  // CRYPTO_AES_CBC with 16-byte key

    /// AES-192 in CBC mode (192-bit key).
    case aes192CBC = 1011  // Internal marker

    /// AES-256 in CBC mode (256-bit key).
    case aes256CBC = 2011  // Internal marker

    /// AES-128 in CTR mode.
    case aes128CTR = 23  // CRYPTO_AES_ICM with 16-byte key

    /// AES-256 in CTR mode.
    case aes256CTR = 2023  // Internal marker

    /// AES-128 in XTS mode (for disk encryption).
    case aes128XTS = 22  // CRYPTO_AES_XTS

    /// AES-256 in XTS mode.
    case aes256XTS = 2022  // Internal marker

    /// ChaCha20 stream cipher.
    case chacha20 = 31  // CRYPTO_CHACHA20

    /// The kernel algorithm constant.
    var kernelAlgorithm: UInt32 {
        switch self {
        case .aes128CBC, .aes192CBC, .aes256CBC:
            return UInt32(COPENCRYPTO_AES_CBC)
        case .aes128CTR, .aes256CTR:
            return UInt32(COPENCRYPTO_AES_CTR)
        case .aes128XTS, .aes256XTS:
            return UInt32(COPENCRYPTO_AES_XTS)
        case .chacha20:
            return UInt32(COPENCRYPTO_CHACHA20)
        }
    }

    /// Required key size in bytes.
    public var keySize: Int {
        switch self {
        case .aes128CBC, .aes128CTR, .aes128XTS:
            return 16
        case .aes192CBC:
            return 24
        case .aes256CBC, .aes256CTR, .aes256XTS:
            return 32
        case .chacha20:
            return 32
        }
    }

    /// Block size in bytes (for block ciphers).
    public var blockSize: Int {
        switch self {
        case .aes128CBC, .aes192CBC, .aes256CBC,
             .aes128CTR, .aes256CTR,
             .aes128XTS, .aes256XTS:
            return 16
        case .chacha20:
            return 64
        }
    }

    /// IV size in bytes.
    public var ivSize: Int {
        switch self {
        case .aes128CBC, .aes192CBC, .aes256CBC,
             .aes128CTR, .aes256CTR,
             .aes128XTS, .aes256XTS:
            return 16
        case .chacha20:
            return 16
        }
    }
}

/// Hash algorithms supported by OpenCrypto.
public enum HashAlgorithm: UInt32, Sendable {
    /// SHA-1 (160-bit digest). Deprecated for security use.
    case sha1 = 14  // CRYPTO_SHA1

    /// SHA-224 (224-bit digest).
    case sha224 = 34  // CRYPTO_SHA2_224

    /// SHA-256 (256-bit digest). Recommended for general use.
    case sha256 = 35  // CRYPTO_SHA2_256

    /// SHA-384 (384-bit digest).
    case sha384 = 36  // CRYPTO_SHA2_384

    /// SHA-512 (512-bit digest).
    case sha512 = 37  // CRYPTO_SHA2_512

    /// BLAKE2b (up to 512-bit digest).
    case blake2b = 29  // CRYPTO_BLAKE2B

    /// BLAKE2s (up to 256-bit digest).
    case blake2s = 30  // CRYPTO_BLAKE2S

    /// The kernel algorithm constant.
    var kernelAlgorithm: UInt32 {
        return rawValue
    }

    /// The HMAC variant of this hash.
    var hmacAlgorithm: UInt32 {
        switch self {
        case .sha1:
            return UInt32(COPENCRYPTO_SHA1_HMAC)
        case .sha224:
            return UInt32(CRYPTO_SHA2_224_HMAC)
        case .sha256:
            return UInt32(COPENCRYPTO_SHA2_256_HMAC)
        case .sha384:
            return UInt32(COPENCRYPTO_SHA2_384_HMAC)
        case .sha512:
            return UInt32(COPENCRYPTO_SHA2_512_HMAC)
        case .blake2b, .blake2s:
            return rawValue  // BLAKE2 has built-in keying
        }
    }

    /// Digest size in bytes.
    public var digestSize: Int {
        switch self {
        case .sha1:
            return 20
        case .sha224:
            return 28
        case .sha256:
            return 32
        case .sha384:
            return 48
        case .sha512:
            return 64
        case .blake2b:
            return 64
        case .blake2s:
            return 32
        }
    }

    /// Block size in bytes.
    public var blockSize: Int {
        switch self {
        case .sha1, .sha224, .sha256:
            return 64
        case .sha384, .sha512:
            return 128
        case .blake2b:
            return 128
        case .blake2s:
            return 64
        }
    }
}

/// AEAD (Authenticated Encryption with Associated Data) algorithms.
public enum AEADAlgorithm: UInt32, Sendable {
    /// AES-GCM with 128-bit key.
    case aes128GCM = 25

    /// AES-GCM with 256-bit key.
    case aes256GCM = 2025

    /// AES-CCM with 128-bit key.
    case aes128CCM = 40

    /// AES-CCM with 256-bit key.
    case aes256CCM = 2040

    /// ChaCha20-Poly1305 (256-bit key).
    case chacha20Poly1305 = 41

    /// The kernel algorithm constant.
    var kernelAlgorithm: UInt32 {
        switch self {
        case .aes128GCM, .aes256GCM:
            return UInt32(COPENCRYPTO_AES_GCM)
        case .aes128CCM, .aes256CCM:
            return UInt32(COPENCRYPTO_AES_CCM)
        case .chacha20Poly1305:
            return UInt32(COPENCRYPTO_CHACHA20_POLY1305)
        }
    }

    /// Required key size in bytes.
    public var keySize: Int {
        switch self {
        case .aes128GCM, .aes128CCM:
            return 16
        case .aes256GCM, .aes256CCM, .chacha20Poly1305:
            return 32
        }
    }

    /// Standard nonce/IV size in bytes.
    public var nonceSize: Int {
        switch self {
        case .aes128GCM, .aes256GCM:
            return 12
        case .aes128CCM, .aes256CCM:
            return 12
        case .chacha20Poly1305:
            return 12
        }
    }

    /// Authentication tag size in bytes.
    public var tagSize: Int {
        return 16
    }
}
