/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation

// MARK: - Birthdate

/// A compact representation of a birthdate for age signal purposes.
///
/// Stores the birthdate as days since the Unix epoch (1970-01-01) using 16 bits.
/// This covers dates from 1970 to approximately 2149 (179 years), which is sufficient
/// for any reasonable birthdate.
///
/// ## Privacy Design
///
/// While this type can be created with explicit date components (for administrative tools
/// like `agectl`), the age signal query API only returns ``AgeBracket`` values—never the
/// underlying birthdate. The ``description`` property also redacts the actual date.
///
/// Applications querying age signals via ``AgeSignalClient`` receive only the bracket,
/// ensuring minimal data exposure as required by AB-1043.
public struct Birthdate: Sendable, Equatable, Hashable {
    /// Days since 1970-01-01
    internal let daysSinceEpoch: UInt16

    // Reference date: 1970-01-01 00:00:00 UTC
    private static let epochComponents = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(identifier: "UTC"),
        year: 1970, month: 1, day: 1
    )

    private static var epochDate: Date {
        epochComponents.date!
    }

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // MARK: - Initialization

    /// Creates a birthdate from year, month, and day components.
    ///
    /// - Parameters:
    ///   - year: The birth year (1970-2149)
    ///   - month: The birth month (1-12)
    ///   - day: The birth day (1-31)
    /// - Throws: `AgeSignalError.invalidBirthdate` if the date is invalid or out of range
    public init(year: Int, month: Int, day: Int) throws {
        let components = DateComponents(
            calendar: Self.calendar,
            timeZone: TimeZone(identifier: "UTC"),
            year: year, month: month, day: day
        )

        guard let date = components.date else {
            throw AgeSignalError.invalidBirthdate("Invalid date: \(year)-\(month)-\(day)")
        }

        try self.init(from: date)
    }

    /// Creates a birthdate from a Date object.
    ///
    /// - Parameter date: The birth date
    /// - Throws: `AgeSignalError.invalidBirthdate` if the date is before 1970 or too far in the future
    public init(from date: Date) throws {
        let days = Self.calendar.dateComponents([.day], from: Self.epochDate, to: date).day ?? 0

        guard days >= 0 else {
            throw AgeSignalError.invalidBirthdate("Birthdate cannot be before 1970-01-01")
        }

        guard days <= Int(UInt16.max) else {
            throw AgeSignalError.invalidBirthdate("Birthdate is too far in the future")
        }

        self.daysSinceEpoch = UInt16(days)
    }

    /// Creates a birthdate from a string in YYYY-MM-DD format.
    ///
    /// - Parameter string: Date string in YYYY-MM-DD format
    /// - Throws: `AgeSignalError.invalidBirthdate` if the string format is invalid
    public init(parsing string: String) throws {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            throw AgeSignalError.invalidBirthdate("Invalid format. Expected YYYY-MM-DD, got: \(string)")
        }

        try self.init(year: year, month: month, day: day)
    }

    /// Creates a birthdate from serialized data (2 bytes, big-endian).
    ///
    /// - Parameter data: 2 bytes containing the days since epoch (big-endian)
    /// - Throws: `AgeSignalError.invalidBirthdate` if data is not 2 bytes
    public init(deserializing data: Data) throws {
        guard data.count == 2 else {
            throw AgeSignalError.invalidBirthdate("Expected 2 bytes, got \(data.count)")
        }

        self.daysSinceEpoch = UInt16(data[0]) << 8 | UInt16(data[1])
    }

    // Internal initializer for raw days
    internal init(daysSinceEpoch: UInt16) {
        self.daysSinceEpoch = daysSinceEpoch
    }

    // MARK: - Serialization

    /// Serializes the birthdate to 2 bytes (big-endian).
    ///
    /// This format is used for storage in extended attributes.
    public func serialize() -> Data {
        Data([
            UInt8((daysSinceEpoch >> 8) & 0xFF),
            UInt8(daysSinceEpoch & 0xFF)
        ])
    }

    // MARK: - Age Calculation

    /// Computes the current age bracket based on today's date.
    ///
    /// - Returns: The age bracket for the person with this birthdate
    public func currentBracket() -> AgeBracket {
        bracket(asOf: Date())
    }

    /// Computes the age bracket as of a specific date.
    ///
    /// - Parameter date: The date to compute the age for
    /// - Returns: The age bracket for the person with this birthdate as of the given date
    public func bracket(asOf date: Date) -> AgeBracket {
        let age = ageInYears(asOf: date)

        if age < 13 {
            return .under13
        } else if age < 16 {
            return .age13to15
        } else if age < 18 {
            return .age16to17
        } else {
            return .adult
        }
    }

    /// Calculates the age in years as of today.
    ///
    /// - Returns: The age in years
    public func ageInYears() -> Int {
        ageInYears(asOf: Date())
    }

    /// Calculates the age in years as of a specific date.
    ///
    /// - Parameter date: The date to calculate the age for
    /// - Returns: The age in years
    public func ageInYears(asOf date: Date) -> Int {
        let birthDate = Self.calendar.date(byAdding: .day, value: Int(daysSinceEpoch), to: Self.epochDate)!
        let components = Self.calendar.dateComponents([.year], from: birthDate, to: date)
        return components.year ?? 0
    }

    /// Returns the birthdate as a Date object.
    ///
    /// Note: This is intentionally not public to avoid exposing the actual birthdate.
    /// Only age brackets should be exposed via the API.
    internal var date: Date {
        Self.calendar.date(byAdding: .day, value: Int(daysSinceEpoch), to: Self.epochDate)!
    }
}

// MARK: - CustomStringConvertible

extension Birthdate: CustomStringConvertible {
    /// Returns a string representation (redacted for privacy).
    ///
    /// The actual date is not exposed to protect privacy. Use `bracket()` instead.
    public var description: String {
        "Birthdate(bracket: \(currentBracket()))"
    }

    /// Returns the date in YYYY-MM-DD format.
    ///
    /// Note: This is internal to avoid exposing the actual birthdate externally.
    internal var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
