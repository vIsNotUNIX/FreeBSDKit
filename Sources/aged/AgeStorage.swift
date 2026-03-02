/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FreeBSDKit
import AgeSignal
import Capabilities
import Descriptors

// MARK: - AgeStorage

/// Manages birthdate storage in the aged database directory.
///
/// Each user's birthdate is stored as an extended attribute on an empty file
/// located at `<databasePath>/<uid>`. The attribute contains a 2-byte compact
/// birthdate (days since Unix epoch in big-endian format).
///
/// ## Capsicum Capability Mode
///
/// This actor is designed to work within Capsicum capability mode. It uses a
/// `DirectoryCapability` for all file operations rather than absolute paths,
/// allowing it to function after `cap_enter()`.
///
/// The database directory and all files are owned by root with mode 0700/0600,
/// ensuring only the daemon can access the data.
actor AgeStorage {
    private let directory: DirectoryCapability
    private let namespace: ExtAttrNamespace = .user
    private let attributeName = AgeSignalProtocol.birthdateAttribute

    // MARK: - Initialization

    /// Creates a new storage actor with a directory capability.
    ///
    /// - Parameter directory: A capability for the database directory.
    ///   This should be opened before entering capability mode.
    init(directory: consuming DirectoryCapability) {
        self.directory = directory
    }

    // MARK: - File Operations

    /// Returns the filename for a given UID.
    private func filename(for uid: UInt32) -> String {
        "\(uid)"
    }

    /// Ensures the file for a UID exists.
    ///
    /// Creates an empty file if it doesn't exist.
    ///
    /// - Parameter uid: The user ID
    /// - Throws: `AgeSignalError.storageError` on failure
    private func ensureFile(for uid: UInt32) throws {
        let name = filename(for: uid)

        // Check if file exists
        do {
            _ = try directory.stat(path: name)
            return  // File exists
        } catch {
            // File doesn't exist, create it
        }

        // Create empty file with mode 0600
        let fd = try directory.openFile(
            path: name,
            flags: [.create, .writeOnly, .closeOnExec],
            mode: 0o600
        )
        Glibc.close(fd)
    }

    // MARK: - Birthdate Operations

    /// Gets the birthdate for a user.
    ///
    /// - Parameter uid: The user ID
    /// - Returns: The birthdate, or `nil` if not set
    /// - Throws: `AgeSignalError.storageError` on I/O failure
    func getBirthdate(uid: UInt32) throws -> Birthdate? {
        let name = filename(for: uid)

        // Check if file exists
        do {
            _ = try directory.stat(path: name)
        } catch {
            return nil  // File doesn't exist
        }

        // Open the file to read extended attributes
        let fd: Int32
        do {
            fd = try directory.openFile(path: name, flags: [.readOnly, .closeOnExec])
        } catch {
            return nil
        }
        defer { Glibc.close(fd) }

        // Get the attribute using file descriptor
        do {
            guard let data = try ExtendedAttributes.get(
                fd: fd,
                namespace: namespace,
                name: attributeName
            ) else {
                return nil
            }

            return try Birthdate(deserializing: data)
        } catch let error as ExtAttrError {
            // Check if it's an ENOATTR error (attribute not found)
            if case .getFailed(_, _, _, let errno) = error, errno == ENOATTR {
                return nil
            }
            throw AgeSignalError.storageError("Failed to read birthdate for UID \(uid): \(error)")
        }
    }

    /// Sets the birthdate for a user.
    ///
    /// - Parameters:
    ///   - uid: The user ID
    ///   - birthdate: The birthdate to set
    /// - Throws: `AgeSignalError.storageError` on I/O failure
    func setBirthdate(uid: UInt32, birthdate: Birthdate) throws {
        try ensureFile(for: uid)
        let name = filename(for: uid)
        let data = birthdate.serialize()

        // Open the file to set extended attributes
        let fd = try directory.openFile(path: name, flags: [.writeOnly, .closeOnExec])
        defer { Glibc.close(fd) }

        do {
            try ExtendedAttributes.set(
                fd: fd,
                namespace: namespace,
                name: attributeName,
                data: data
            )
        } catch let error as ExtAttrError {
            throw AgeSignalError.storageError("Failed to set birthdate for UID \(uid): \(error)")
        }
    }

    /// Removes the birthdate for a user.
    ///
    /// - Parameter uid: The user ID
    /// - Throws: `AgeSignalError.storageError` on I/O failure
    func removeBirthdate(uid: UInt32) throws {
        let name = filename(for: uid)

        // Check if file exists
        do {
            _ = try directory.stat(path: name)
        } catch {
            return  // Nothing to remove
        }

        // Open the file to delete the attribute
        let fd: Int32
        do {
            fd = try directory.openFile(path: name, flags: [.writeOnly, .closeOnExec])
        } catch {
            return  // Can't open, nothing to remove
        }
        defer { Glibc.close(fd) }

        // Delete the attribute (idempotent)
        do {
            try ExtendedAttributes.delete(
                fd: fd,
                namespace: namespace,
                name: attributeName
            )
        } catch let error as ExtAttrError {
            // Ignore ENOATTR errors - attribute might not exist
            if case .deleteFailed(_, _, _, let errno) = error, errno == ENOATTR {
                // OK - attribute didn't exist
            } else {
                throw AgeSignalError.storageError("Failed to remove birthdate for UID \(uid): \(error)")
            }
        }

        // Delete the empty file using unlinkat
        try directory.unlink(path: name)
    }

    /// Gets the current age bracket for a user.
    ///
    /// Retrieves the birthdate and computes the bracket based on today's date.
    ///
    /// - Parameter uid: The user ID
    /// - Returns: The age bracket, or `nil` if birthdate not set
    /// - Throws: `AgeSignalError.storageError` on I/O failure
    func getBracket(uid: UInt32) throws -> AgeBracket? {
        guard let birthdate = try getBirthdate(uid: uid) else {
            return nil
        }
        return birthdate.currentBracket()
    }
}
