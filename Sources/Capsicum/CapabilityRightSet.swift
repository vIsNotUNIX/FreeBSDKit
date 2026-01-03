/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import CCapsicum

/// A set of capability rights for a file descriptor, wrapping `cap_rights_t`.
///
/// `CapabilityRightSet` allows you to manage, merge, and validate Capsicum
/// capability rights in a type-safe Swift way.
public struct CapabilityRightSet: Sendable {
    private var rights: cap_rights_t

    // MARK: - Initializers

    /// Initializes an empty `CapabilityRightSet`.
    ///
    /// All rights are cleared initially. Use `add(capability:)` to add rights.
    public init() {
        var rights = cap_rights_t()
        ccapsicum_rights_init(&rights)
        self.rights = rights
    }

    /// Initializes a `CapabilityRightSet` from an existing `cap_rights_t`.
    ///
    /// - Parameter rights: A `cap_rights_t` structure representing the rights.
    public init(rights: cap_rights_t) {
        self.rights = rights
    }

    /// Initializes a `CapabilityRightSet` from an array of `CapabilityRight`.
    ///
    /// - Parameter rights: An array of `CapabilityRight` to include in the set.
    public init(rights inRights: [CapabilityRight]) {
        self.rights = {
            var rights = cap_rights_t()
            ccapsicum_rights_init(&rights)
            for right in inRights {
                ccaspsicum_cap_set(&rights, right.bridged)
            }
            return rights
        }()
    }

    // MARK: - Modifiers

    /// Adds a single capability to the set.
    ///
    /// - Parameter capability: The capability to add.
    public mutating func add(capability: CapabilityRight) {
        ccaspsicum_cap_set(&self.rights, capability.bridged)
    }

    /// Adds multiple capabilities to the set.
    ///
    /// - Parameter capabilities: An array of capabilities to add.
    public mutating func add(capabilites: [CapabilityRight]) {
        for cap in capabilites {
            ccaspsicum_cap_set(&self.rights, cap.bridged)
        }
    }

    /// Removes a single capability from the set.
    ///
    /// - Parameter capability: The capability to remove.
    public mutating func clear(capability: CapabilityRight) {
        ccapsicum_rights_clear(&self.rights, capability.bridged)
    }

    /// Removes multiple capabilities from the set.
    ///
    /// - Parameter capabilities: An array of capabilities to remove.
    public mutating func clear(capabilites: [CapabilityRight]) {
        for cap in capabilites {
            ccapsicum_rights_clear(&self.rights, cap.bridged)
        }
    }

    // MARK: - Queries

    /// Checks whether the set contains a given capability.
    ///
    /// - Parameter capability: The capability to check for.
    /// - Returns: `true` if the capability is present; otherwise, `false`.
    public mutating func contains(capability: CapabilityRight) -> Bool {
        return ccapsicum_right_is_set(&self.rights, capability.bridged)
    }

    /// Checks whether the set contains all rights from another `CapabilityRightSet`.
    ///
    /// - Parameter other: Another `CapabilityRightSet` to check.
    /// - Returns: `true` if all rights from `other` are included in this set.
    public mutating func contains(right other: CapabilityRightSet) -> Bool {
        var contains = false
        withUnsafePointer(to: other.rights) { otherRights in
            contains = ccapsicum_rights_contains(&self.rights, otherRights)
        }
        return contains
    }

    // MARK: - Set Operations

    /// Merges rights from another `CapabilityRightSet` into this set.
    ///
    /// - Parameter other: The set of rights to merge.
    public mutating func merge(with other: CapabilityRightSet) {
        withUnsafePointer(to: other.rights) { srcPtr in
            _ = ccapsicum_cap_rights_merge(&self.rights, srcPtr)
        }
    }

    /// Removes rights that match another `CapabilityRightSet`.
    ///
    /// - Parameter right: The set of rights to remove from this set.
    public mutating func remove(matching right: CapabilityRightSet) {
        withUnsafePointer(to: right.rights) { srcPtr in
            _ = ccapsicum_rights_remove(&self.rights, srcPtr)
        }
    }

    // MARK: - Validation

    /// Validates that the rights set is well-formed.
    ///
    /// - Returns: `true` if the set is valid; otherwise, `false`.
    public mutating func validate() -> Bool {
        return ccapsicum_rights_valid(&rights)
    }

    // MARK: - Accessors

    /// Returns the underlying `cap_rights_t` structure.
    ///
    /// - Returns: The raw `cap_rights_t` representing this set.
    public func asCapRightsT() -> cap_rights_t {
        return rights
    }
}
