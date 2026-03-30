/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

/// Errors that can occur during OpenCrypto operations.
public enum CryptoError: Error, Equatable {
    /// Failed to open /dev/crypto.
    case openFailed(errno: Int32)

    /// Failed to create a crypto session.
    case sessionFailed(errno: Int32)

    /// Invalid key size for the algorithm.
    case invalidKeySize(expected: Int, got: Int)

    /// Invalid IV size for the algorithm.
    case invalidIVSize(expected: Int, got: Int)

    /// Invalid input size (must be multiple of block size for some algorithms).
    case invalidInputSize(message: String)

    /// Crypto operation failed.
    case operationFailed(errno: Int32)

    /// Authentication tag verification failed.
    case authenticationFailed

    /// Algorithm not supported by hardware.
    case algorithmNotSupported
}

extension CryptoError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .openFailed(let errno):
            return "Failed to open /dev/crypto: \(String(cString: strerror(errno)))"
        case .sessionFailed(let errno):
            return "Failed to create crypto session: \(String(cString: strerror(errno)))"
        case .invalidKeySize(let expected, let got):
            return "Invalid key size: expected \(expected) bytes, got \(got)"
        case .invalidIVSize(let expected, let got):
            return "Invalid IV size: expected \(expected) bytes, got \(got)"
        case .invalidInputSize(let message):
            return "Invalid input size: \(message)"
        case .operationFailed(let errno):
            return "Crypto operation failed: \(String(cString: strerror(errno)))"
        case .authenticationFailed:
            return "Authentication tag verification failed"
        case .algorithmNotSupported:
            return "Algorithm not supported by hardware"
        }
    }
}
