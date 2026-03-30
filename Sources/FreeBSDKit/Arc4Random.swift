/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

/// Swift interface to FreeBSD's arc4random(3) functions.
///
/// Provides fast, cryptographically secure random numbers using the
/// kernel's ChaCha20-based CSPRNG. Unlike `getrandom(2)`, arc4random:
/// - Never blocks (always has entropy available)
/// - Auto-reseeds from kernel entropy pool
/// - Is fork-safe (reseeds after fork)
///
/// ## Example
/// ```swift
/// // Get a random UInt32
/// let value = Arc4Random.uint32()
///
/// // Get a bounded random value [0, upperBound)
/// let diceRoll = Arc4Random.uniform(6) + 1
///
/// // Fill a buffer
/// var key = [UInt8](repeating: 0, count: 32)
/// Arc4Random.fill(&key)
///
/// // Get typed random values
/// let nonce: UInt64 = Arc4Random.value()
/// ```
public enum Arc4Random {

    // MARK: - Basic Functions

    /// Returns a random 32-bit unsigned integer.
    ///
    /// - Returns: A uniformly distributed random UInt32.
    @inlinable
    public static func uint32() -> UInt32 {
        return arc4random()
    }

    /// Returns a random integer uniformly distributed in [0, upperBound).
    ///
    /// This avoids modulo bias that would occur with `arc4random() % n`.
    ///
    /// - Parameter upperBound: The exclusive upper bound (must be > 0).
    /// - Returns: A random value in the range [0, upperBound).
    @inlinable
    public static func uniform(_ upperBound: UInt32) -> UInt32 {
        return arc4random_uniform(upperBound)
    }

    /// Fills a buffer with random bytes.
    ///
    /// - Parameter buffer: The buffer to fill with random bytes.
    @inlinable
    public static func fill(_ buffer: inout [UInt8]) {
        buffer.withUnsafeMutableBytes { ptr in
            arc4random_buf(ptr.baseAddress!, ptr.count)
        }
    }

    /// Fills a raw buffer with random bytes.
    ///
    /// - Parameters:
    ///   - pointer: Pointer to buffer to fill.
    ///   - count: Number of bytes to generate.
    @inlinable
    public static func fill(_ pointer: UnsafeMutableRawPointer, count: Int) {
        arc4random_buf(pointer, count)
    }

    // MARK: - Convenience Functions

    /// Returns an array of random bytes.
    ///
    /// - Parameter count: Number of bytes to generate.
    /// - Returns: Array of random bytes.
    public static func bytes(_ count: Int) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        fill(&buffer)
        return buffer
    }

    /// Returns a random value of the specified type.
    ///
    /// - Returns: A random value of type T.
    ///
    /// ## Example
    /// ```swift
    /// let id: UInt64 = Arc4Random.value()
    /// let flags: UInt16 = Arc4Random.value()
    /// ```
    public static func value<T>() -> T {
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        defer { ptr.deallocate() }
        arc4random_buf(ptr, size)
        return ptr.load(as: T.self)
    }

    /// Returns a random boolean value.
    ///
    /// - Returns: true or false with equal probability.
    @inlinable
    public static func bool() -> Bool {
        return arc4random() & 1 == 1
    }

    /// Returns a random integer in the given range.
    ///
    /// - Parameter range: The range of possible values.
    /// - Returns: A random value within the range.
    ///
    /// ## Example
    /// ```swift
    /// let port = Arc4Random.in(1024..<65536)  // Random unprivileged port
    /// ```
    public static func `in`(_ range: Range<Int>) -> Int {
        let span = UInt32(range.count)
        return range.lowerBound + Int(uniform(span))
    }

    /// Returns a random integer in the given closed range.
    ///
    /// - Parameter range: The closed range of possible values.
    /// - Returns: A random value within the range.
    ///
    /// ## Example
    /// ```swift
    /// let die = Arc4Random.in(1...6)  // Dice roll
    /// ```
    public static func `in`(_ range: ClosedRange<Int>) -> Int {
        let span = UInt32(range.count)
        return range.lowerBound + Int(uniform(span))
    }

    /// Shuffles an array in place using Fisher-Yates algorithm.
    ///
    /// - Parameter array: The array to shuffle.
    public static func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = Int(uniform(UInt32(i + 1)))
            array.swapAt(i, j)
        }
    }

    /// Returns a shuffled copy of the array.
    ///
    /// - Parameter array: The array to shuffle.
    /// - Returns: A new array with elements in random order.
    public static func shuffled<T>(_ array: [T]) -> [T] {
        var copy = array
        shuffle(&copy)
        return copy
    }

    /// Selects a random element from a collection.
    ///
    /// - Parameter collection: The collection to select from.
    /// - Returns: A random element, or nil if the collection is empty.
    public static func element<C: Collection>(from collection: C) -> C.Element?
    where C.Index == Int {
        guard !collection.isEmpty else { return nil }
        let index = Int(uniform(UInt32(collection.count)))
        return collection[index]
    }
}
