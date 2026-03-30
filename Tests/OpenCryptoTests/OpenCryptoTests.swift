/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import OpenCrypto

final class OpenCryptoTests: XCTestCase {

    var crypto: OpenCrypto!

    override func setUpWithError() throws {
        // /dev/crypto may not be available in all environments
        do {
            crypto = try OpenCrypto()
        } catch CryptoError.openFailed {
            throw XCTSkip("/dev/crypto not available")
        }
    }

    // MARK: - Cipher Tests

    func testAES256CBCRoundtrip() throws {
        let key = [UInt8](repeating: 0x42, count: 32)
        let iv = [UInt8](repeating: 0x00, count: 16)
        let plaintext = [UInt8]("Hello, OpenCrypto! This is a test message.".utf8)

        // Pad to block size
        let padded = pkcs7Pad(plaintext, blockSize: 16)

        let cipher = try crypto.cipher(.aes256CBC, key: key)
        let ciphertext = try cipher.encrypt(padded, iv: iv)

        XCTAssertNotEqual(ciphertext, padded)
        XCTAssertEqual(ciphertext.count, padded.count)

        let decrypted = try cipher.decrypt(ciphertext, iv: iv)
        XCTAssertEqual(decrypted, padded)

        let unpadded = pkcs7Unpad(decrypted)
        XCTAssertEqual(unpadded, plaintext)
    }

    func testAES128CBCRoundtrip() throws {
        let key = [UInt8](repeating: 0x42, count: 16)
        let iv = [UInt8](repeating: 0x00, count: 16)
        let plaintext = pkcs7Pad([UInt8]("Test message".utf8), blockSize: 16)

        let cipher = try crypto.cipher(.aes128CBC, key: key)
        let ciphertext = try cipher.encrypt(plaintext, iv: iv)
        let decrypted = try cipher.decrypt(ciphertext, iv: iv)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testInvalidKeySize() throws {
        let badKey = [UInt8](repeating: 0x42, count: 15)  // Should be 16

        do {
            _ = try crypto.cipher(.aes128CBC, key: badKey)
            XCTFail("Expected invalidKeySize error")
        } catch let error as CryptoError {
            guard case .invalidKeySize(let expected, let got) = error else {
                XCTFail("Expected invalidKeySize error, got \(error)")
                return
            }
            XCTAssertEqual(expected, 16)
            XCTAssertEqual(got, 15)
        }
    }

    func testInvalidIVSize() throws {
        let key = [UInt8](repeating: 0x42, count: 16)
        let badIV = [UInt8](repeating: 0x00, count: 8)  // Should be 16
        let plaintext = [UInt8](repeating: 0x00, count: 16)

        let cipher = try crypto.cipher(.aes128CBC, key: key)

        XCTAssertThrowsError(try cipher.encrypt(plaintext, iv: badIV)) { error in
            guard case CryptoError.invalidIVSize = error else {
                XCTFail("Expected invalidIVSize error")
                return
            }
        }
    }

    func testInvalidInputSize() throws {
        let key = [UInt8](repeating: 0x42, count: 16)
        let iv = [UInt8](repeating: 0x00, count: 16)
        let plaintext = [UInt8]("Not aligned".utf8)  // 11 bytes, not multiple of 16

        let cipher = try crypto.cipher(.aes128CBC, key: key)

        XCTAssertThrowsError(try cipher.encrypt(plaintext, iv: iv)) { error in
            guard case CryptoError.invalidInputSize = error else {
                XCTFail("Expected invalidInputSize error")
                return
            }
        }
    }

    func testEncryptInPlace() throws {
        let key = [UInt8](repeating: 0x42, count: 16)
        let iv = [UInt8](repeating: 0x00, count: 16)
        var data = pkcs7Pad([UInt8]("In-place test".utf8), blockSize: 16)
        let original = data

        let cipher = try crypto.cipher(.aes128CBC, key: key)
        try cipher.encryptInPlace(&data, iv: iv)

        XCTAssertNotEqual(data, original)

        try cipher.decryptInPlace(&data, iv: iv)
        XCTAssertEqual(data, original)
    }

    // MARK: - Hash Tests

    func testSHA256() throws {
        let hasher = try crypto.hash(.sha256)
        let data = [UInt8]("hello".utf8)
        let digest = try hasher.hash(data)

        XCTAssertEqual(digest.count, 32)

        // Known SHA256 of "hello"
        let expected: [UInt8] = [
            0x2c, 0xf2, 0x4d, 0xba, 0x5f, 0xb0, 0xa3, 0x0e,
            0x26, 0xe8, 0x3b, 0x2a, 0xc5, 0xb9, 0xe2, 0x9e,
            0x1b, 0x16, 0x1e, 0x5c, 0x1f, 0xa7, 0x42, 0x5e,
            0x73, 0x04, 0x33, 0x62, 0x93, 0x8b, 0x98, 0x24
        ]
        XCTAssertEqual(digest, expected)
    }

    func testSHA512() throws {
        let hasher = try crypto.hash(.sha512)
        let data = [UInt8]("test".utf8)
        let digest = try hasher.hash(data)

        XCTAssertEqual(digest.count, 64)
    }

    func testHMACSHA256() throws {
        let key = [UInt8]("secret".utf8)
        let hmac = try crypto.hmac(.sha256, key: key)
        let message = [UInt8]("message".utf8)
        let mac = try hmac.authenticate(message)

        XCTAssertEqual(mac.count, 32)

        // Verify same input produces same output
        let mac2 = try hmac.authenticate(message)
        XCTAssertEqual(mac, mac2)
    }

    func testHMACVerify() throws {
        let key = [UInt8]("secret".utf8)
        let hmac = try crypto.hmac(.sha256, key: key)
        let message = [UInt8]("message".utf8)
        let mac = try hmac.authenticate(message)

        XCTAssertTrue(try hmac.verify(message, tag: mac))

        // Wrong message should fail
        let wrongMessage = [UInt8]("wrong".utf8)
        XCTAssertFalse(try hmac.verify(wrongMessage, tag: mac))

        // Wrong tag should fail
        var wrongTag = mac
        wrongTag[0] ^= 0xFF
        XCTAssertFalse(try hmac.verify(message, tag: wrongTag))
    }

    // MARK: - AEAD Tests

    func testAESGCMRoundtrip() throws {
        let key = [UInt8](repeating: 0x42, count: 32)
        let nonce = [UInt8](repeating: 0x00, count: 12)
        let plaintext = [UInt8]("Hello, AEAD!".utf8)
        let aad = [UInt8]("header".utf8)

        let aead = try crypto.aead(.aes256GCM, key: key)
        let (ciphertext, tag) = try aead.seal(plaintext, nonce: nonce, aad: aad)

        XCTAssertEqual(ciphertext.count, plaintext.count)
        XCTAssertEqual(tag.count, 16)
        XCTAssertNotEqual(ciphertext, plaintext)

        let decrypted = try aead.open(ciphertext, nonce: nonce, aad: aad, tag: tag)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESGCMAuthenticationFailure() throws {
        let key = [UInt8](repeating: 0x42, count: 32)
        let nonce = [UInt8](repeating: 0x00, count: 12)
        let plaintext = [UInt8]("Secret".utf8)

        let aead = try crypto.aead(.aes256GCM, key: key)
        let (ciphertext, tag) = try aead.seal(plaintext, nonce: nonce)

        // Tamper with ciphertext
        var tampered = ciphertext
        tampered[0] ^= 0xFF

        XCTAssertThrowsError(try aead.open(tampered, nonce: nonce, tag: tag)) { error in
            // Should fail authentication
            if case CryptoError.authenticationFailed = error {
                // Expected
            } else if case CryptoError.operationFailed = error {
                // Also acceptable - some implementations return EBADMSG
            } else {
                XCTFail("Expected authentication failure, got \(error)")
            }
        }
    }

    func testAESGCMCombined() throws {
        let key = [UInt8](repeating: 0x42, count: 16)
        let nonce = [UInt8](repeating: 0x00, count: 12)
        let plaintext = [UInt8]("Combined mode test".utf8)

        let aead = try crypto.aead(.aes128GCM, key: key)
        let combined = try aead.sealCombined(plaintext, nonce: nonce)

        XCTAssertEqual(combined.count, plaintext.count + 16)

        let decrypted = try aead.openCombined(combined, nonce: nonce)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testChaCha20Poly1305() throws {
        let key = [UInt8](repeating: 0x42, count: 32)
        let nonce = [UInt8](repeating: 0x00, count: 12)
        let plaintext = [UInt8]("ChaCha20-Poly1305 test".utf8)
        let aad = [UInt8]("associated data".utf8)

        let aead = try crypto.aead(.chacha20Poly1305, key: key)
        let (ciphertext, tag) = try aead.seal(plaintext, nonce: nonce, aad: aad)

        XCTAssertEqual(tag.count, 16)

        let decrypted = try aead.open(ciphertext, nonce: nonce, aad: aad, tag: tag)
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - Helper Functions

    private func pkcs7Pad(_ data: [UInt8], blockSize: Int) -> [UInt8] {
        let padLen = blockSize - (data.count % blockSize)
        return data + [UInt8](repeating: UInt8(padLen), count: padLen)
    }

    private func pkcs7Unpad(_ data: [UInt8]) -> [UInt8] {
        guard let last = data.last, last > 0, Int(last) <= data.count else {
            return data
        }
        return Array(data.dropLast(Int(last)))
    }
}
