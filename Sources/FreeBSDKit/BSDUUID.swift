/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CUUID
import Glibc

/// A universally unique identifier (UUID) using FreeBSD's native implementation.
///
/// This provides UUID generation and manipulation without requiring Foundation,
/// using FreeBSD's DCE 1.1 compatible UUID implementation.
///
/// ## Example
/// ```swift
/// // Generate a new UUID
/// let uuid = try BSDUUID()
///
/// // Generate multiple UUIDs efficiently (batch mode)
/// let uuids = try BSDUUID.generate(count: 10)
///
/// // Parse from string
/// let parsed = try BSDUUID(string: "550e8400-e29b-41d4-a716-446655440000")
///
/// // Convert to string
/// print(uuid.string)  // "550e8400-e29b-41d4-a716-446655440000"
/// ```
public struct BSDUUID: Hashable, Sendable {
    /// The raw 16-byte UUID data.
    public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// Creates a new UUID by generating one from the kernel.
    ///
    /// This generates a DCE version 1 (time-based) UUID.
    ///
    /// - Throws: `UUIDError` if UUID generation fails.
    public init() throws {
        var cuuid = cuuid_bytes_t()
        guard cuuid_generate(&cuuid, 1) == 0 else {
            throw UUIDError.systemError(errno)
        }
        self.bytes = Self.fromCUUID(cuuid)
    }

    /// Creates a UUID from raw bytes.
    ///
    /// - Parameter bytes: The 16 bytes of the UUID.
    public init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        self.bytes = bytes
    }

    /// Creates a UUID from a byte array.
    ///
    /// - Parameter array: A 16-byte array.
    /// - Throws: `UUIDError.invalidLength` if array is not 16 bytes.
    public init(bytes array: [UInt8]) throws {
        guard array.count == 16 else {
            throw UUIDError.invalidLength(array.count)
        }
        self.bytes = (array[0], array[1], array[2], array[3],
                      array[4], array[5], array[6], array[7],
                      array[8], array[9], array[10], array[11],
                      array[12], array[13], array[14], array[15])
    }

    /// Parses a UUID from its string representation.
    ///
    /// Accepts hyphenated format ("550e8400-e29b-41d4-a716-446655440000").
    /// Empty string parses as the nil UUID.
    ///
    /// - Parameter string: The UUID string.
    /// - Throws: `UUIDError.invalidString` if parsing fails.
    public init(string: String) throws {
        var cuuid = cuuid_bytes_t()
        guard cuuid_from_string(string, &cuuid) == 0 else {
            throw UUIDError.invalidString(string)
        }
        self.bytes = Self.fromCUUID(cuuid)
    }

    /// Generates multiple UUIDs efficiently.
    ///
    /// When generating many UUIDs, batch generation is more efficient
    /// as the kernel generates them as a dense set.
    ///
    /// - Parameter count: Number of UUIDs to generate (max 2048).
    /// - Returns: Array of generated UUIDs.
    /// - Throws: `UUIDError` if generation fails.
    public static func generate(count: Int) throws -> [BSDUUID] {
        guard count > 0 && count <= 2048 else {
            throw UUIDError.invalidCount(count)
        }

        var cuuids = [cuuid_bytes_t](repeating: cuuid_bytes_t(), count: count)
        guard cuuid_generate(&cuuids, Int32(count)) == 0 else {
            throw UUIDError.systemError(errno)
        }

        return cuuids.map { Self(cuuid: $0) }
    }

    /// The nil UUID (all zeros).
    public static let zero = BSDUUID(bytes: (0, 0, 0, 0, 0, 0, 0, 0,
                                             0, 0, 0, 0, 0, 0, 0, 0))

    /// Returns true if this is the nil UUID.
    public var isNil: Bool {
        var cuuid = toCUUID()
        return cuuid_is_nil(&cuuid) != 0
    }

    /// The UUID as a hyphenated string.
    ///
    /// Format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" (lowercase)
    public var string: String {
        var cuuid = toCUUID()
        guard let cstr = cuuid_to_string(&cuuid) else {
            return ""
        }
        defer { free(cstr) }
        return String(cString: cstr)
    }

    /// The UUID as a compact string (no hyphens).
    public var compactString: String {
        String(string.filter { $0 != "-" })
    }

    /// The UUID as a byte array.
    public var byteArray: [UInt8] {
        [bytes.0, bytes.1, bytes.2, bytes.3,
         bytes.4, bytes.5, bytes.6, bytes.7,
         bytes.8, bytes.9, bytes.10, bytes.11,
         bytes.12, bytes.13, bytes.14, bytes.15]
    }

    /// The UUID version (1-5, or 0 for nil/invalid).
    public var version: Int {
        // Version is in bits 4-7 of byte 6 (time_hi_and_version high nibble)
        Int((bytes.6 & 0xF0) >> 4)
    }

    /// The UUID variant.
    public var variant: Variant {
        let bits = bytes.8
        if bits & 0x80 == 0 {
            return .ncs
        } else if bits & 0xC0 == 0x80 {
            return .rfc4122
        } else if bits & 0xE0 == 0xC0 {
            return .microsoft
        } else {
            return .future
        }
    }

    /// UUID variant types.
    public enum Variant: Sendable {
        /// NCS backward compatibility
        case ncs
        /// RFC 4122 (DCE 1.1)
        case rfc4122
        /// Microsoft GUID
        case microsoft
        /// Reserved for future use
        case future
    }

    // MARK: - Private

    private init(cuuid: cuuid_bytes_t) {
        self.bytes = Self.fromCUUID(cuuid)
    }

    private static func fromCUUID(_ cuuid: cuuid_bytes_t) -> (UInt8, UInt8, UInt8, UInt8,
                                                               UInt8, UInt8, UInt8, UInt8,
                                                               UInt8, UInt8, UInt8, UInt8,
                                                               UInt8, UInt8, UInt8, UInt8) {
        let b = cuuid.bytes
        return (b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15)
    }

    private func toCUUID() -> cuuid_bytes_t {
        var cuuid = cuuid_bytes_t()
        cuuid.bytes = (bytes.0, bytes.1, bytes.2, bytes.3,
                       bytes.4, bytes.5, bytes.6, bytes.7,
                       bytes.8, bytes.9, bytes.10, bytes.11,
                       bytes.12, bytes.13, bytes.14, bytes.15)
        return cuuid
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: bytes) { hasher.combine(bytes: $0) }
    }

    public static func == (lhs: BSDUUID, rhs: BSDUUID) -> Bool {
        withUnsafeBytes(of: lhs.bytes) { lhsPtr in
            withUnsafeBytes(of: rhs.bytes) { rhsPtr in
                memcmp(lhsPtr.baseAddress, rhsPtr.baseAddress, 16) == 0
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension BSDUUID: CustomStringConvertible {
    public var description: String {
        string
    }
}

// MARK: - Comparable

extension BSDUUID: Comparable {
    public static func < (lhs: BSDUUID, rhs: BSDUUID) -> Bool {
        var lhsCUUID = lhs.toCUUID()
        var rhsCUUID = rhs.toCUUID()
        return cuuid_compare(&lhsCUUID, &rhsCUUID) < 0
    }
}

// MARK: - Codable

extension BSDUUID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(string: string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// MARK: - Error

/// Errors that can occur during UUID operations.
public enum UUIDError: Error, Sendable {
    /// The byte array length was not 16.
    case invalidLength(Int)
    /// The string could not be parsed as a UUID.
    case invalidString(String)
    /// The requested count is invalid (must be 1-2048).
    case invalidCount(Int)
    /// A system call failed.
    case systemError(Int32)
}

extension UUIDError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidLength(let length):
            return "UUID must be 16 bytes, got \(length)"
        case .invalidString(let string):
            return "Invalid UUID string: \(string)"
        case .invalidCount(let count):
            return "UUID count must be 1-2048, got \(count)"
        case .systemError(let errno):
            return "UUID system error: \(errno)"
        }
    }
}
