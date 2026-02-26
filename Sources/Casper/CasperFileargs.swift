/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// File arguments service for Capsicum sandboxes.
///
/// `CasperFileargs` provides access to files specified on the command line
/// from within a capability-mode sandbox. This is particularly useful for
/// utilities that need to process files provided as arguments while running
/// in a sandbox.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode, initialize with command line args
/// let fileargs = try CasperFileargs(
///     arguments: CommandLine.arguments,
///     flags: O_RDONLY,
///     operations: [.open, .lstat]
/// )
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Open files from the sandbox
/// if let fd = fileargs.open("input.txt") {
///     // Use the file descriptor
/// }
/// ```
///
/// - Important: `CasperFileargs` must be initialized before entering capability mode.
public struct CasperFileargs: ~Copyable, Sendable {
    /// The underlying fileargs handle (opaque pointer to fileargs_t).
    private nonisolated(unsafe) let handle: UnsafeMutableRawPointer

    /// Operations that can be performed on files.
    public struct Operations: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Allow opening files.
        public static let open = Operations(rawValue: CCASPER_FA_OPEN)
        /// Allow lstat on files.
        public static let lstat = Operations(rawValue: CCASPER_FA_LSTAT)
        /// Allow realpath on files.
        public static let realpath = Operations(rawValue: CCASPER_FA_REALPATH)

        /// All operations.
        public static let all: Operations = [.open, .lstat, .realpath]
    }

    /// Creates a file arguments service.
    ///
    /// - Parameters:
    ///   - arguments: Command line arguments (typically `CommandLine.arguments`).
    ///   - flags: File open flags (e.g., `O_RDONLY`, `O_WRONLY`).
    ///   - mode: File mode for creating files (default 0).
    ///   - rights: Capsicum capability rights (optional).
    ///   - operations: Allowed operations on files.
    /// - Throws: `CasperError.initFailed` if initialization fails.
    public init(
        arguments: [String],
        flags: Int32,
        mode: mode_t = 0,
        rights: UnsafeMutablePointer<cap_rights_t>? = nil,
        operations: Operations
    ) throws {
        // Convert arguments to C-style argv
        var cStrings = arguments.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }

        let result = cStrings.withUnsafeMutableBufferPointer { buffer in
            ccasper_fileargs_init(
                Int32(buffer.count),
                buffer.baseAddress,
                flags,
                mode,
                rights,
                operations.rawValue
            )
        }

        guard let fa = result else {
            throw CasperError.initFailed
        }
        self.handle = fa
    }

    /// Creates a file arguments service using a Casper channel.
    ///
    /// - Parameters:
    ///   - casper: The main Casper channel.
    ///   - arguments: Command line arguments.
    ///   - flags: File open flags.
    ///   - mode: File mode for creating files.
    ///   - rights: Capsicum capability rights (optional).
    ///   - operations: Allowed operations on files.
    /// - Throws: `CasperError.initFailed` if initialization fails.
    public init(
        casper: borrowing CasperChannel,
        arguments: [String],
        flags: Int32,
        mode: mode_t = 0,
        rights: UnsafeMutablePointer<cap_rights_t>? = nil,
        operations: Operations
    ) throws {
        var cStrings = arguments.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }

        let result = cStrings.withUnsafeMutableBufferPointer { buffer in
            casper.withUnsafeChannel { chan in
                ccasper_fileargs_cinit(
                    chan,
                    Int32(buffer.count),
                    buffer.baseAddress,
                    flags,
                    mode,
                    rights,
                    operations.rawValue
                )
            }
        }

        guard let fa = result else {
            throw CasperError.initFailed
        }
        self.handle = fa
    }

    /// Internal initializer for wrap().
    private init(handle: UnsafeMutableRawPointer) {
        self.handle = handle
    }

    /// Opens a file by name.
    ///
    /// The file must have been specified in the arguments when the service
    /// was initialized.
    ///
    /// - Parameter name: The filename to open.
    /// - Returns: A file descriptor, or -1 on error.
    public func open(_ name: String) -> Int32 {
        name.withCString { namePtr in
            ccasper_fileargs_open(handle, namePtr)
        }
    }

    /// Opens a file as a FILE stream.
    ///
    /// - Parameters:
    ///   - name: The filename to open.
    ///   - mode: The fopen mode string (e.g., "r", "w", "a").
    /// - Returns: A FILE pointer, or `nil` on error.
    public func fopen(_ name: String, mode: String) -> OpaquePointer? {
        let result = name.withCString { namePtr in
            mode.withCString { modePtr in
                ccasper_fileargs_fopen(handle, namePtr, modePtr)
            }
        }
        return result.map { OpaquePointer($0) }
    }

    /// Gets file status using lstat.
    ///
    /// - Parameter name: The filename to stat.
    /// - Returns: File status on success, or `nil` on error.
    public func lstat(_ name: String) -> stat? {
        var sb = stat()
        let result = name.withCString { namePtr in
            ccasper_fileargs_lstat(handle, namePtr, &sb)
        }
        guard result == 0 else { return nil }
        return sb
    }

    /// Resolves a pathname to an absolute path.
    ///
    /// - Parameter pathname: The path to resolve.
    /// - Returns: The resolved absolute path, or `nil` on error.
    public func realpath(_ pathname: String) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = pathname.withCString { pathPtr in
            ccasper_fileargs_realpath(handle, pathPtr, &buffer)
        }
        guard result != nil else { return nil }
        return buffer.withUnsafeBytes { ptr in
            let utf8 = ptr.bindMemory(to: UInt8.self)
            let length = utf8.firstIndex(of: 0) ?? utf8.count
            return String(decoding: utf8.prefix(length), as: UTF8.self)
        }
    }

    /// Wraps a Casper channel as a fileargs handle.
    ///
    /// - Parameters:
    ///   - channel: The channel to wrap (consumed).
    ///   - fdflags: File descriptor flags.
    /// - Returns: A fileargs handle.
    /// - Throws: `CasperError.initFailed` if wrapping fails.
    public static func wrap(channel: consuming CasperChannel, fdflags: Int32) throws -> CasperFileargs {
        let fa = channel.withUnsafeChannel { chan in
            ccasper_fileargs_wrap(chan, fdflags)
        }
        guard let handle = fa else {
            throw CasperError.initFailed
        }
        return CasperFileargs(handle: handle)
    }

    deinit {
        ccasper_fileargs_free(handle)
    }
}
