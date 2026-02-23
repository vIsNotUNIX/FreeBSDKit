/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

/// Represents a single file and its associated security labels.
///
/// A `FileLabel` is the default implementation of `Labelable` for filesystem-based
/// security labels. It specifies which security attributes (key-value pairs) should be
/// applied to a specific file via FreeBSD extended attributes in the MAC framework namespace.
///
/// ## Example
/// ```swift
/// let label = FileLabel(
///     path: "/bin/sh",
///     attributes: [
///         "type": "shell",
///         "trust": "system",
///         "network": "deny"
///     ]
/// )
/// ```
public struct FileLabel: Labelable {
    /// Absolute path to the file to be labeled
    public let path: String

    /// Security attributes as key-value pairs.
    ///
    /// **Key constraints**:
    /// - Must not be empty
    /// - Must not contain `=`, newlines, or null bytes
    ///
    /// **Value constraints**:
    /// - May contain `=` (parsed with maxSplits: 1)
    /// - Must not contain newlines or null bytes
    /// - May be empty (empty values are allowed)
    public let attributes: [String: String]

    /// Validates that the file exists on the filesystem.
    ///
    /// This validation is a critical safety check to ensure that labels are only
    /// applied to files that actually exist, preventing partial policy application.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if the file does not exist
    /// - Throws: ``LabelError/invalidConfiguration`` if the path is invalid
    public func validate() throws {
        // Path should not be empty
        guard !path.isEmpty else {
            throw LabelError.invalidConfiguration("File path cannot be empty")
        }

        // Path should not contain null bytes
        guard !path.contains("\0") else {
            throw LabelError.invalidConfiguration("File path '\(path)' contains null bytes")
        }

        // Check if file exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw LabelError.fileNotFound(path)
        }
    }

    /// Returns the symlink target if this path is a symbolic link.
    ///
    /// This is useful for informing users that a label will be applied to the
    /// target file, not the symlink itself. FreeBSD extended attribute operations
    /// follow symlinks by default.
    ///
    /// - Returns: The resolved target path if this is a symlink, `nil` otherwise
    public func symlinkTarget() -> String? {
        var statBuf = stat()
        guard lstat(path, &statBuf) == 0 else {
            return nil
        }

        // Check if it's a symlink (S_IFLNK)
        guard (statBuf.st_mode & S_IFMT) == S_IFLNK else {
            return nil
        }

        // Read the symlink target
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let len = readlink(path, &buffer, buffer.count - 1)
        guard len > 0 else {
            return nil
        }

        buffer[len] = 0
        return String(cString: buffer)
    }

    /// Returns the fully resolved path, following all symlinks.
    ///
    /// - Returns: The canonical path with all symlinks resolved, or `nil` on error
    public func resolvedPath() -> String? {
        guard let resolved = realpath(path, nil) else {
            return nil
        }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}


/// Type alias for FileLabel-based configuration (most common use case).
public typealias FileLabelConfiguration = LabelConfiguration<FileLabel>