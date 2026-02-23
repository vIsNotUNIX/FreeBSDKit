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
    /// Absolute path to the file to be labeled.
    ///
    /// Can be either:
    /// - A specific file path: `/bin/sh`
    /// - A recursive pattern: `/usr/bin/*` (labels all files recursively)
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

    // MARK: - Recursive Pattern Support

    /// Whether this path is a recursive pattern (ends with `/*`).
    ///
    /// Recursive patterns apply the label to all regular files in the
    /// directory tree, excluding directories and special files.
    public var isRecursivePattern: Bool {
        path.hasSuffix("/*")
    }

    /// The directory path for recursive patterns.
    ///
    /// For `/usr/bin/*` returns `/usr/bin`.
    /// For regular paths, returns `nil`.
    public var directoryPath: String? {
        guard isRecursivePattern else { return nil }
        return String(path.dropLast(2))  // Remove "/*"
    }

    /// Expands this label to all matching file paths.
    ///
    /// For recursive patterns (`/path/*`), returns all regular files
    /// in the directory tree. For regular paths, returns just the path.
    ///
    /// **Note**: Only regular files are included. Directories, symlinks to
    /// directories, and special files are excluded.
    ///
    /// - Returns: Array of file paths this label applies to
    /// - Throws: ``LabelError`` if directory doesn't exist or can't be read
    public func expandedPaths() throws -> [String] {
        guard isRecursivePattern, let dirPath = directoryPath else {
            // Regular path - just return it
            return [path]
        }

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LabelError.invalidConfiguration(
                "Recursive pattern '\(path)' - '\(dirPath)' is not a directory"
            )
        }

        // Enumerate all files recursively
        var files: [String] = []
        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: dirPath),
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        guard let enumerator = enumerator else {
            throw LabelError.invalidConfiguration(
                "Cannot enumerate directory '\(dirPath)'"
            )
        }

        for case let fileURL as URL in enumerator {
            // Check if it's a regular file (or symlink to regular file)
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    files.append(fileURL.path)
                }
            } catch {
                // Skip files we can't access
                continue
            }
        }

        return files.sorted()
    }

    /// Creates expanded FileLabel instances for each file in a recursive pattern.
    ///
    /// - Returns: Array of FileLabel instances, one per file
    /// - Throws: ``LabelError`` if expansion fails
    public func expandedLabels() throws -> [FileLabel] {
        let paths = try expandedPaths()
        return paths.map { FileLabel(path: $0, attributes: self.attributes) }
    }

    // MARK: - Validation

    /// Validates that the file or directory pattern exists on the filesystem.
    ///
    /// For recursive patterns, validates that the directory exists.
    /// For regular paths, validates that the file exists.
    ///
    /// - Throws: ``LabelError/fileNotFound`` if the file/directory does not exist
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

        if isRecursivePattern {
            // For recursive patterns, validate directory exists
            guard let dirPath = directoryPath else {
                throw LabelError.invalidConfiguration("Invalid recursive pattern: \(path)")
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory) else {
                throw LabelError.fileNotFound(dirPath)
            }
            guard isDirectory.boolValue else {
                throw LabelError.invalidConfiguration(
                    "Recursive pattern '\(path)' - '\(dirPath)' is not a directory"
                )
            }
        } else {
            // Regular path - check if file exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                throw LabelError.fileNotFound(path)
            }
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