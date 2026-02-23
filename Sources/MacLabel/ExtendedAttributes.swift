/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc

// MARK: - ExtendedAttributes

/// Swift wrapper for FreeBSD extended attribute operations.
///
/// Provides type-safe access to FreeBSD's `extattr_*` family of functions.
/// For MACF security labeling, use the `.system` namespace with the attribute
/// name specified in your configuration file.
///
/// ## MACF Integration
///
/// Different MACF policies can use different attribute names:
/// - `"mac.labels"` - General purpose security labels
/// - `"mac.network"` - Network policy labels
/// - `"mac.filesystem"` - Filesystem policy labels
/// - `"mac.custom"` - Custom policy labels
///
/// ## C API Compatibility
///
/// The attribute format is designed to be easily readable from C:
/// ```c
/// // Example C code to read labels
/// char buf[4096];
/// const char *attr_name = "mac.labels";  // From configuration
/// ssize_t len = extattr_get_file(path, EXTATTR_NAMESPACE_SYSTEM,
///                                 attr_name, buf, sizeof(buf));
/// // Parse as newline-separated key=value pairs
/// ```
///
public struct ExtendedAttributes {

    /// Sets an extended attribute on a file.
    ///
    /// **Requires**: Root privileges when using `.system` namespace.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the file (must exist)
    ///   - namespace: Attribute namespace (`.system` for MACF labels)
    ///   - name: Attribute name (from configuration file)
    ///   - data: Attribute value data (newline-separated key=value pairs for labels)
    /// - Throws: ``LabelError/extAttrSetFailed`` on failure
    public static func set(
        path: String,
        namespace: ExtAttrNamespace,
        name: String,
        data: Data
    ) throws {
        // Validate inputs
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid path for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        // Capture errno immediately after syscall to avoid Swift/Foundation overwriting it
        let (result, err): (Int, Int32) = data.withUnsafeBytes { bytes in
            let rc = extattr_set_file(
                path,
                namespace.rawValue,
                name,
                bytes.baseAddress,
                bytes.count
            )
            return (rc, errno)
        }

        guard result >= 0 else {
            throw LabelError.extAttrSetFailed(path: path, errno: err)
        }
    }

    /// Gets an extended attribute from a file.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the file
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Returns: Attribute data, or `nil` if attribute doesn't exist
    /// - Throws: ``LabelError/extAttrGetFailed`` on error other than ENOATTR
    public static func get(
        path: String,
        namespace: ExtAttrNamespace,
        name: String
    ) throws -> Data? {
        // Validate inputs
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid path for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        // Retry loop to handle race conditions where attribute size changes
        for attempt in 0..<3 {
            // First, get the size
            let size = extattr_get_file(path, namespace.rawValue, name, nil, 0)
            let sizeErrno = errno

            // ENOATTR means attribute doesn't exist (not an error)
            if size < 0 {
                if sizeErrno == ENOATTR {
                    return nil
                }
                throw LabelError.extAttrGetFailed(path: path, errno: sizeErrno)
            }

            // Empty attribute (exists but has no data)
            if size == 0 {
                return Data()
            }

            // Allocate buffer and read - capture errno immediately
            var buffer = Data(count: Int(size))
            let (result, readErrno): (Int, Int32) = buffer.withUnsafeMutableBytes { bytes in
                let rc = extattr_get_file(
                    path,
                    namespace.rawValue,
                    name,
                    bytes.baseAddress,
                    bytes.count
                )
                return (rc, errno)
            }

            if result < 0 {
                // Attribute was deleted between size query and read
                if readErrno == ENOATTR {
                    return nil
                }
                // Buffer too small (attribute grew) - retry
                if readErrno == ERANGE && attempt < 2 {
                    continue
                }
                throw LabelError.extAttrGetFailed(path: path, errno: readErrno)
            }

            // Successful read - resize buffer to actual data size
            buffer.count = Int(result)
            return buffer
        }

        // Should not reach here, but if retry exhausted
        throw LabelError.extAttrGetFailed(path: path, errno: ERANGE)
    }

    /// Deletes an extended attribute from a file.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the file
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Throws: ``LabelError/extAttrDeleteFailed`` on failure
    public static func delete(
        path: String,
        namespace: ExtAttrNamespace,
        name: String
    ) throws {
        // Validate inputs
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid path for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        let result = extattr_delete_file(path, namespace.rawValue, name)
        let err = errno

        guard result >= 0 else {
            // ENOATTR is not an error for delete (idempotent operation)
            if err == ENOATTR {
                return
            }
            throw LabelError.extAttrDeleteFailed(path: path, errno: err)
        }
    }

    /// Lists all extended attribute names in a namespace.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the file
    ///   - namespace: Attribute namespace
    /// - Returns: Array of attribute names
    /// - Throws: ``LabelError/extAttrListFailed`` on failure or malformed data
    public static func list(
        path: String,
        namespace: ExtAttrNamespace
    ) throws -> [String] {
        // Validate inputs
        guard !path.isEmpty && !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid path for extended attribute operation")
        }

        // Get size needed
        let size = extattr_list_file(path, namespace.rawValue, nil, 0)
        let sizeErrno = errno

        guard size >= 0 else {
            throw LabelError.extAttrListFailed(path: path, errno: sizeErrno)
        }

        if size == 0 {
            return []
        }

        // Read list - capture errno immediately
        var buffer = Data(count: Int(size))
        let (result, readErrno): (Int, Int32) = buffer.withUnsafeMutableBytes { bytes in
            let rc = extattr_list_file(
                path,
                namespace.rawValue,
                bytes.baseAddress,
                bytes.count
            )
            return (rc, errno)
        }

        guard result >= 0 else {
            throw LabelError.extAttrListFailed(path: path, errno: readErrno)
        }

        // Parse the list format: length-prefixed strings
        // Format: [len1][name1][len2][name2]...
        // where len is UInt8
        var names: [String] = []
        var offset = 0

        while offset < buffer.count {
            // Ensure we can read the length byte
            guard offset < buffer.count else {
                throw LabelError.extAttrListFailed(
                    path: path,
                    errno: EINVAL  // Malformed list data
                )
            }

            let len = Int(buffer[offset])
            offset += 1

            // Ensure we have enough data for the name
            guard offset + len <= buffer.count else {
                throw LabelError.extAttrListFailed(
                    path: path,
                    errno: EINVAL  // Truncated list data
                )
            }

            // Decode name - require valid UTF-8
            guard let name = String(
                data: buffer[offset..<offset + len],
                encoding: .utf8
            ) else {
                throw LabelError.extAttrListFailed(
                    path: path,
                    errno: EILSEQ  // Invalid character sequence
                )
            }

            names.append(name)
            offset += len
        }

        return names
    }

    /// Sets an extended attribute on an open file descriptor.
    ///
    /// **TOCTOU Protection**: Operating on file descriptors instead of paths
    /// prevents time-of-check-time-of-use attacks where a file is replaced
    /// between validation and labeling.
    ///
    /// - Parameters:
    ///   - fd: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    ///   - data: Attribute value data
    /// - Throws: ``LabelError/extAttrSetFailed`` on failure
    public static func setFd(
        fd: Int32,
        namespace: ExtAttrNamespace,
        name: String,
        data: Data
    ) throws {
        // Validate inputs
        guard fd >= 0 else {
            throw LabelError.invalidConfiguration("Invalid file descriptor for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        let (result, err): (Int, Int32) = data.withUnsafeBytes { bytes in
            let rc = extattr_set_fd(
                fd,
                namespace.rawValue,
                name,
                bytes.baseAddress,
                bytes.count
            )
            return (rc, errno)
        }

        guard result >= 0 else {
            throw LabelError.extAttrSetFailed(path: "fd:\(fd)", errno: err)
        }
    }

    /// Gets an extended attribute from an open file descriptor.
    ///
    /// - Parameters:
    ///   - fd: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Returns: Attribute data, or `nil` if attribute doesn't exist
    /// - Throws: ``LabelError/extAttrGetFailed`` on error
    public static func getFd(
        fd: Int32,
        namespace: ExtAttrNamespace,
        name: String
    ) throws -> Data? {
        // Validate inputs
        guard fd >= 0 else {
            throw LabelError.invalidConfiguration("Invalid file descriptor for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        for attempt in 0..<3 {
            let size = extattr_get_fd(fd, namespace.rawValue, name, nil, 0)
            let sizeErrno = errno

            if size < 0 {
                if sizeErrno == ENOATTR {
                    return nil
                }
                throw LabelError.extAttrGetFailed(path: "fd:\(fd)", errno: sizeErrno)
            }

            if size == 0 {
                return Data()
            }

            var buffer = Data(count: Int(size))
            let (result, readErrno): (Int, Int32) = buffer.withUnsafeMutableBytes { bytes in
                let rc = extattr_get_fd(
                    fd,
                    namespace.rawValue,
                    name,
                    bytes.baseAddress,
                    bytes.count
                )
                return (rc, errno)
            }

            if result < 0 {
                if readErrno == ENOATTR {
                    return nil
                }
                if readErrno == ERANGE && attempt < 2 {
                    continue
                }
                throw LabelError.extAttrGetFailed(path: "fd:\(fd)", errno: readErrno)
            }

            buffer.count = Int(result)
            return buffer
        }

        throw LabelError.extAttrGetFailed(path: "fd:\(fd)", errno: ERANGE)
    }

    /// Deletes an extended attribute from an open file descriptor.
    ///
    /// - Parameters:
    ///   - fd: Open file descriptor
    ///   - namespace: Attribute namespace
    ///   - name: Attribute name
    /// - Throws: ``LabelError/extAttrDeleteFailed`` on failure
    public static func deleteFd(
        fd: Int32,
        namespace: ExtAttrNamespace,
        name: String
    ) throws {
        // Validate inputs
        guard fd >= 0 else {
            throw LabelError.invalidConfiguration("Invalid file descriptor for extended attribute operation")
        }
        guard !name.isEmpty && !name.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid attribute name for extended attribute operation")
        }

        let result = extattr_delete_fd(fd, namespace.rawValue, name)
        let err = errno

        guard result >= 0 else {
            if err == ENOATTR {
                return
            }
            throw LabelError.extAttrDeleteFailed(path: "fd:\(fd)", errno: err)
        }
    }
}
