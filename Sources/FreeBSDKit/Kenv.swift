/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc

// kenv(2) syscall - not exported by Glibc module
@_silgen_name("kenv")
private func kenv(_ action: Int32, _ name: UnsafePointer<CChar>?, _ value: UnsafeMutablePointer<CChar>?, _ len: Int32) -> Int32

/// Access to FreeBSD kernel environment variables.
///
/// Kernel environment variables are set at boot time by the loader and can be
/// used to configure kernel behavior. They differ from regular environment
/// variables in that they exist in kernel space and persist across process
/// boundaries.
///
/// ## Reading Variables
/// ```swift
/// // Get a single variable
/// if let hostname = Kenv["kern.hostname"] {
///     print("Kernel hostname: \(hostname)")
/// }
///
/// // Get with default value
/// let verbose = Kenv.get("boot_verbose") ?? "0"
///
/// // Check if a variable exists
/// if Kenv.exists("acpi.rsdp") {
///     print("ACPI RSDP address available")
/// }
/// ```
///
/// ## Listing Variables
/// ```swift
/// // Dump all kernel environment variables
/// for (name, value) in try Kenv.dump() {
///     print("\(name)=\(value)")
/// }
///
/// // Get only hardware hints
/// let hints = try Kenv.dump().filter { $0.name.hasPrefix("hint.") }
///
/// // Get boot environment list
/// let bootenvs = try Kenv.dump().filter { $0.name.hasPrefix("bootenvs") }
/// ```
///
/// ## Loader and Static Environments
/// ```swift
/// // Dump loader environment (what loader(8) provided)
/// if let loaderEnv = try? Kenv.dumpLoader() {
///     print("Loader provided \(loaderEnv.count) variables")
/// }
///
/// // Dump static environment (compiled into kernel)
/// if let staticEnv = try? Kenv.dumpStatic() {
///     for item in staticEnv {
///         print("Static: \(item.name)=\(item.value)")
///     }
/// }
/// ```
///
/// ## Modifying Variables (Root Only)
/// ```swift
/// // Set a variable (requires root)
/// do {
///     try Kenv.set("debug.verbose", value: "1")
/// } catch KenvError.permissionDenied {
///     print("Must be root to set kernel variables")
/// }
///
/// // Unset a variable (requires root)
/// try Kenv.unset("debug.verbose")
/// ```
///
/// ## Common Variables
/// ```swift
/// // ACPI information
/// let oemId = Kenv["acpi.oem"]
/// let rsdp = Kenv["acpi.rsdp"]
///
/// // Boot configuration
/// let bootDev = Kenv["currdev"]
/// let rootFs = Kenv["vfs.root.mountfrom"]
///
/// // Hardware hints
/// let uartPort = Kenv["hint.uart.0.port"]
/// let uartIrq = Kenv["hint.uart.0.irq"]
///
/// // Module loading
/// let loadAcpi = Kenv["acpi_load"]
/// ```
public enum Kenv {

    // MARK: - Get

    /// Gets a kernel environment variable.
    ///
    /// - Parameter name: The variable name (max 128 characters).
    /// - Returns: The value, or `nil` if not found.
    ///
    /// ## Example
    /// ```swift
    /// if let rsdp = Kenv.get("acpi.rsdp") {
    ///     print("ACPI RSDP: \(rsdp)")
    /// }
    /// ```
    public static func get(_ name: String) -> String? {
        guard name.count <= KENV_MNAMELEN else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(KENV_MVALLEN) + 1)
        let result = name.withCString { namePtr in
            kenv(KENV_GET, namePtr, &buffer, Int32(buffer.count))
        }

        guard result >= 0 else { return nil }
        return String(cString: buffer)
    }

    /// Subscript access for getting variables.
    ///
    /// ## Example
    /// ```swift
    /// let hostname = Kenv["kern.hostname"]
    /// let verbose = Kenv["boot_verbose"] ?? "0"
    /// ```
    public static subscript(name: String) -> String? {
        return get(name)
    }

    /// Checks if a kernel environment variable exists.
    ///
    /// - Parameter name: The variable name.
    /// - Returns: `true` if the variable exists.
    ///
    /// ## Example
    /// ```swift
    /// if Kenv.exists("acpi.rsdp") {
    ///     print("ACPI tables available")
    /// }
    /// ```
    public static func exists(_ name: String) -> Bool {
        get(name) != nil
    }

    // MARK: - Set (Root Only)

    /// Sets a kernel environment variable.
    ///
    /// - Parameters:
    ///   - name: The variable name (max 128 characters).
    ///   - value: The value to set (max 128 characters).
    /// - Throws: `KenvError.permissionDenied` if not root,
    ///           `KenvError.nameTooLong` or `KenvError.valueTooLong` if exceeded.
    ///
    /// ## Example
    /// ```swift
    /// // Requires root privileges
    /// try Kenv.set("debug.verbose", value: "1")
    /// ```
    public static func set(_ name: String, value: String) throws {
        guard name.count <= KENV_MNAMELEN else {
            throw KenvError.nameTooLong(name.count)
        }
        guard value.count <= KENV_MVALLEN else {
            throw KenvError.valueTooLong(value.count)
        }

        let result = name.withCString { namePtr in
            value.withCString { valuePtr in
                // kenv expects value length including null terminator
                kenv(KENV_SET, namePtr, UnsafeMutablePointer(mutating: valuePtr), Int32(value.utf8.count + 1))
            }
        }

        if result < 0 {
            let err = errno
            switch err {
            case EPERM:
                throw KenvError.permissionDenied
            case EINVAL:
                throw KenvError.invalidArgument
            default:
                throw KenvError.systemError(err)
            }
        }
    }

    // MARK: - Unset (Root Only)

    /// Unsets a kernel environment variable.
    ///
    /// - Parameter name: The variable name.
    /// - Throws: `KenvError.permissionDenied` if not root.
    ///
    /// ## Example
    /// ```swift
    /// // Requires root privileges
    /// try Kenv.unset("debug.verbose")
    /// ```
    public static func unset(_ name: String) throws {
        guard name.count <= KENV_MNAMELEN else {
            throw KenvError.nameTooLong(name.count)
        }

        let result = name.withCString { namePtr in
            kenv(KENV_UNSET, namePtr, nil, 0)
        }

        if result < 0 {
            let err = errno
            switch err {
            case EPERM:
                throw KenvError.permissionDenied
            case ENOENT:
                throw KenvError.notFound(name)
            case EINVAL:
                throw KenvError.invalidArgument
            default:
                throw KenvError.systemError(err)
            }
        }
    }

    // MARK: - Dump

    /// A kernel environment variable entry.
    public struct Entry: Equatable, Sendable {
        /// The variable name.
        public let name: String
        /// The variable value.
        public let value: String
    }

    /// Dumps all dynamic kernel environment variables.
    ///
    /// - Returns: Array of name-value pairs.
    /// - Throws: `KenvError` if the dump fails.
    ///
    /// ## Example
    /// ```swift
    /// // List all variables
    /// for entry in try Kenv.dump() {
    ///     print("\(entry.name)=\(entry.value)")
    /// }
    ///
    /// // Filter for ACPI variables
    /// let acpi = try Kenv.dump().filter { $0.name.hasPrefix("acpi.") }
    ///
    /// // Find all device hints
    /// let hints = try Kenv.dump().filter { $0.name.hasPrefix("hint.") }
    /// ```
    public static func dump() throws -> [Entry] {
        try dumpWithAction(KENV_DUMP)
    }

    /// Dumps the loader environment (provided by loader(8)).
    ///
    /// This returns the environment that was passed to the kernel by the
    /// bootloader. Requires kernel to be configured with `PRESERVE_EARLY_ENVIRONMENTS`.
    ///
    /// - Returns: Array of name-value pairs.
    /// - Throws: `KenvError` if not available or fails.
    ///
    /// ## Example
    /// ```swift
    /// if let loaderEnv = try? Kenv.dumpLoader() {
    ///     print("Loader environment has \(loaderEnv.count) entries")
    /// }
    /// ```
    public static func dumpLoader() throws -> [Entry] {
        try dumpWithAction(KENV_DUMP_LOADER)
    }

    /// Dumps the static kernel environment (compiled into kernel).
    ///
    /// This returns environment variables that were compiled into the kernel
    /// via the `env` directive in the kernel config. Requires kernel to be
    /// configured with `PRESERVE_EARLY_ENVIRONMENTS`.
    ///
    /// - Returns: Array of name-value pairs.
    /// - Throws: `KenvError` if not available or fails.
    ///
    /// ## Example
    /// ```swift
    /// if let staticEnv = try? Kenv.dumpStatic() {
    ///     for entry in staticEnv {
    ///         print("Compiled: \(entry.name)=\(entry.value)")
    ///     }
    /// }
    /// ```
    public static func dumpStatic() throws -> [Entry] {
        try dumpWithAction(KENV_DUMP_STATIC)
    }

    // MARK: - Convenience

    /// Gets all variable names.
    ///
    /// ## Example
    /// ```swift
    /// let names = try Kenv.names()
    /// print("Found \(names.count) kernel variables")
    /// ```
    public static func names() throws -> [String] {
        try dump().map(\.name)
    }

    /// Gets variables matching a prefix.
    ///
    /// - Parameter prefix: The prefix to match.
    /// - Returns: Matching entries.
    ///
    /// ## Example
    /// ```swift
    /// // Get all ACPI variables
    /// let acpiVars = try Kenv.withPrefix("acpi.")
    ///
    /// // Get all hints for a device
    /// let uartHints = try Kenv.withPrefix("hint.uart.")
    /// ```
    public static func withPrefix(_ prefix: String) throws -> [Entry] {
        try dump().filter { $0.name.hasPrefix(prefix) }
    }

    /// Gets variables as a dictionary.
    ///
    /// ## Example
    /// ```swift
    /// let env = try Kenv.asDictionary()
    /// if let rsdp = env["acpi.rsdp"] {
    ///     print("RSDP: \(rsdp)")
    /// }
    /// ```
    public static func asDictionary() throws -> [String: String] {
        var dict: [String: String] = [:]
        for entry in try dump() {
            dict[entry.name] = entry.value
        }
        return dict
    }

    // MARK: - Private

    private static func dumpWithAction(_ action: Int32) throws -> [Entry] {
        // First call with NULL to get required size
        let size = kenv(action, nil, nil, 0)
        guard size >= 0 else {
            let err = errno
            switch err {
            case ENOENT:
                throw KenvError.environmentNotPreserved
            default:
                throw KenvError.systemError(err)
            }
        }

        guard size > 0 else { return [] }

        // Allocate buffer and get data
        var buffer = [CChar](repeating: 0, count: Int(size) + 1)
        let namePtr: UnsafePointer<CChar>? = nil
        let result = kenv(action, namePtr, &buffer, Int32(buffer.count))
        guard result == 0 else {
            throw KenvError.systemError(errno)
        }

        // Parse "name=value\0name=value\0..." format
        // Use the size from the first call since result is 0 on success
        return parseEnvironment(buffer, length: Int(size))
    }

    private static func parseEnvironment(_ buffer: [CChar], length: Int) -> [Entry] {
        var entries: [Entry] = []
        var start = 0

        while start < length {
            // Find end of this entry (null terminator)
            var end = start
            while end < length && buffer[end] != 0 {
                end += 1
            }

            if end > start {
                // Convert to string (buffer contains CChars which are Int8)
                let entryBytes = buffer[start..<end].map { UInt8(bitPattern: $0) }
                let entryStr = String(decoding: entryBytes, as: UTF8.self)

                // Split on first '='
                if let eqIndex = entryStr.firstIndex(of: "=") {
                    let name = String(entryStr[..<eqIndex])
                    let value = String(entryStr[entryStr.index(after: eqIndex)...])
                    entries.append(Entry(name: name, value: value))
                }
            }

            start = end + 1
        }

        return entries
    }
}

// MARK: - Constants

private let KENV_GET: Int32 = 0
private let KENV_SET: Int32 = 1
private let KENV_UNSET: Int32 = 2
private let KENV_DUMP: Int32 = 3
private let KENV_DUMP_LOADER: Int32 = 4
private let KENV_DUMP_STATIC: Int32 = 5

private let KENV_MNAMELEN: Int = 128
private let KENV_MVALLEN: Int = 128

// MARK: - Error

/// Errors that can occur during kernel environment operations.
public enum KenvError: Error, Sendable {
    /// The variable was not found.
    case notFound(String)
    /// Permission denied (requires root for set/unset).
    case permissionDenied
    /// The variable name exceeds 128 characters.
    case nameTooLong(Int)
    /// The variable value exceeds 128 characters.
    case valueTooLong(Int)
    /// Invalid argument provided.
    case invalidArgument
    /// The kernel environment is not preserved (for loader/static dumps).
    case environmentNotPreserved
    /// A system call failed.
    case systemError(Int32)
}

extension KenvError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let name):
            return "Kernel environment variable not found: \(name)"
        case .permissionDenied:
            return "Permission denied (requires root)"
        case .nameTooLong(let length):
            return "Variable name too long: \(length) > 128"
        case .valueTooLong(let length):
            return "Variable value too long: \(length) > 128"
        case .invalidArgument:
            return "Invalid argument"
        case .environmentNotPreserved:
            return "Kernel environment not preserved (requires PRESERVE_EARLY_ENVIRONMENTS)"
        case .systemError(let err):
            return "Kernel environment error: \(err)"
        }
    }
}
