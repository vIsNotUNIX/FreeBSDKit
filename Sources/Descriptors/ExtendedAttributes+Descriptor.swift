/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import FreeBSDKit

// MARK: - FileDescriptor Overloads

extension ExtendedAttributes {
    /// Sets an extended attribute on a FileDescriptor.
    ///
    /// **TOCTOU Protection**: Using FileDescriptor ensures the validated
    /// descriptor is the one being modified.
    ///
    /// - Parameters:
    ///   - descriptor: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    ///   - data: Attribute value data
    /// - Throws: ``ExtAttrError`` on failure
    public static func set<D: Descriptor>(
        descriptor: borrowing D,
        namespace: ExtAttrNamespace,
        name: String,
        data: Data
    ) throws where D: ~Copyable {
        try descriptor.unsafe { fd in
            try set(fd: fd, namespace: namespace, name: name, data: data)
        }
    }

    /// Gets an extended attribute from a FileDescriptor.
    ///
    /// - Parameters:
    ///   - descriptor: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Returns: Attribute data, or `nil` if attribute doesn't exist
    /// - Throws: ``ExtAttrError`` on error
    public static func get<D: Descriptor>(
        descriptor: borrowing D,
        namespace: ExtAttrNamespace,
        name: String
    ) throws -> Data? where D: ~Copyable {
        try descriptor.unsafe { fd in
            try get(fd: fd, namespace: namespace, name: name)
        }
    }

    /// Deletes an extended attribute from a FileDescriptor.
    ///
    /// - Parameters:
    ///   - descriptor: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Throws: ``ExtAttrError`` on failure
    public static func delete<D: Descriptor>(
        descriptor: borrowing D,
        namespace: ExtAttrNamespace,
        name: String
    ) throws where D: ~Copyable {
        try descriptor.unsafe { fd in
            try delete(fd: fd, namespace: namespace, name: name)
        }
    }
}
