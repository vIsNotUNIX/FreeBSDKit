/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FreeBSDKit
import AgeSignal

// MARK: - AgeStorage

/// Manages birthdate storage in the aged database directory.
///
/// Each user's birthdate is stored as an extended attribute on an empty file
/// located at `<databasePath>/<uid>`. The attribute contains a 2-byte compact
/// birthdate (days since Unix epoch in big-endian format).
///
/// The database directory and all files are owned by root with mode 0700/0600,
/// ensuring only the daemon can access the data.
actor AgeStorage {
    private let databasePath: String
    private let namespace: ExtAttrNamespace = .user
    private let attributeName = AgeSignalProtocol.birthdateAttribute

    // MARK: - Initialization

    /// Creates a new storage actor.
    ///
    /// - Parameter databasePath: Path to the database directory (default: `/var/db/aged`)
    init(databasePath: String = AgeSignalProtocol.databasePath) {
        self.databasePath = databasePath
    }

    // MARK: - Directory Management

    /// Ensures the database directory exists with proper permissions.
    ///
    /// Creates the directory if it doesn't exist. Sets mode to 0700 (root only).
    ///
    /// - Throws: `AgeSignalError.storageError` if the directory cannot be created or secured.
    func ensureDirectory() throws {
        var st = stat()
        if stat(databasePath, &st) == 0 {
            // Directory exists, verify it's a directory
            if (st.st_mode & S_IFMT) != S_IFDIR {
                throw AgeSignalError.storageError("\(databasePath) exists but is not a directory")
            }
            // Ensure permissions are correct (0700)
            if chmod(databasePath, 0o700) != 0 {
                throw AgeSignalError.storageError("Failed to set permissions on \(databasePath): \(String(cString: strerror(errno)))")
            }
        } else {
            // Create directory
            if mkdir(databasePath, 0o700) != 0 {
                throw AgeSignalError.storageError("Failed to create \(databasePath): \(String(cString: strerror(errno)))")
            }
        }
    }

    // MARK: - File Path

    /// Returns the path to the file for a given UID.
    private func filePath(for uid: UInt32) -> String {
        "\(databasePath)/\(uid)"
    }

    /// Ensures the file for a UID exists.
    ///
    /// Creates an empty file if it doesn't exist.
    ///
    /// - Parameter uid: The user ID
    /// - Throws: `AgeSignalError.storageError` on failure
    private func ensureFile(for uid: UInt32) throws {
        let path = filePath(for: uid)

        var st = stat()
        if stat(path, &st) == 0 {
            // File exists
            return
        }

        // Create empty file with mode 0600
        let fd = open(path, O_CREAT | O_WRONLY | O_CLOEXEC, 0o600)
        if fd < 0 {
            throw AgeSignalError.storageError("Failed to create \(path): \(String(cString: strerror(errno)))")
        }
        close(fd)
    }

    // MARK: - Birthdate Operations

    /// Gets the birthdate for a user.
    ///
    /// - Parameter uid: The user ID
    /// - Returns: The birthdate, or `nil` if not set
    /// - Throws: `AgeSignalError.storageError` on I/O failure
    func getBirthdate(uid: UInt32) throws -> Birthdate? {
        let path = filePath(for: uid)

        // Check if file exists
        var st = stat()
        if stat(path, &st) != 0 {
            if errno == ENOENT {
                return nil
            }
            throw AgeSignalError.storageError("Failed to stat \(path): \(String(cString: strerror(errno)))")
        }

        // Get the attribute
        do {
            guard let data = try ExtendedAttributes.get(
                path: path,
                namespace: namespace,
                name: attributeName
            ) else {
                return nil
            }

            return try Birthdate(deserializing: data)
        } catch let error as ExtAttrError {
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
        let path = filePath(for: uid)
        let data = birthdate.serialize()

        do {
            try ExtendedAttributes.set(
                path: path,
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
        let path = filePath(for: uid)

        // Check if file exists
        var st = stat()
        if stat(path, &st) != 0 {
            if errno == ENOENT {
                return  // Nothing to remove
            }
            throw AgeSignalError.storageError("Failed to stat \(path): \(String(cString: strerror(errno)))")
        }

        // Delete the attribute (idempotent)
        do {
            try ExtendedAttributes.delete(
                path: path,
                namespace: namespace,
                name: attributeName
            )
        } catch let error as ExtAttrError {
            throw AgeSignalError.storageError("Failed to remove birthdate for UID \(uid): \(error)")
        }

        // Optionally delete the empty file too
        unlink(path)
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
