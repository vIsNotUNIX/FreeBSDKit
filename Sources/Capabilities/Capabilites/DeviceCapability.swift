/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Descriptors
import Foundation
import FreeBSDKit

// MARK: - DeviceCapability

/// A capability-wrapped device file descriptor.
///
/// `DeviceCapability` provides capability-safe access to device files,
/// enabling device control operations while maintaining Capsicum security.
///
/// ## Device Types
///
/// FreeBSD supports various device types accessible through `/dev`:
/// - Character devices (terminals, serial ports, pseudo-devices)
/// - Block devices (disks, partitions)
/// - Pseudo-devices (/dev/null, /dev/zero, /dev/random)
///
/// ## Example
/// ```swift
/// // Open a device before entering capability mode
/// let disk = try DeviceCapability.open(path: "/dev/da0", flags: .readOnly)
///
/// // Query device characteristics
/// let mediaSize = try disk.mediaSize()
/// let sectorSize = try disk.sectorSize()
///
/// // Read from device
/// let data = try disk.pread(count: 512, offset: 0)
/// ```
///
/// ## Capsicum Rights
///
/// Common rights for device descriptors:
/// - `CAP_READ` - Read from device
/// - `CAP_WRITE` - Write to device
/// - `CAP_IOCTL` - Perform ioctl operations (can be further limited)
/// - `CAP_SEEK` - Seek on device (if seekable)
/// - `CAP_FSTAT` - Get device status
/// - `CAP_MMAP` / `CAP_MMAP_R` / `CAP_MMAP_RW` - Memory map device
public struct DeviceCapability: Capability, DeviceDescriptor, ~Copyable {
    public typealias RAWBSD = Int32
    private var handle: RawCapabilityHandle

    public init(_ value: RAWBSD) {
        self.handle = RawCapabilityHandle(value)
    }

    public consuming func close() {
        handle.close()
    }

    public consuming func take() -> RAWBSD {
        return handle.take()
    }

    public func unsafe<R>(_ block: (RAWBSD) throws -> R) rethrows -> R where R: ~Copyable {
        try handle.unsafe(block)
    }

    // MARK: - Factory Methods

    /// Opens a device at the given path.
    ///
    /// - Parameters:
    ///   - path: Path to the device (typically under /dev)
    ///   - flags: Open flags (access mode, etc.)
    /// - Returns: A new `DeviceCapability`
    /// - Throws: System error if the device cannot be opened
    public static func open(path: String, flags: OpenAtFlags = [.readOnly]) throws -> DeviceCapability {
        let deviceFlags = flags.union([.closeOnExec])
        let fd = path.withCString { cpath in
            Glibc.open(cpath, deviceFlags.rawValue)
        }
        guard fd >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return DeviceCapability(fd)
    }

    /// Opens a device relative to a directory descriptor.
    ///
    /// - Parameters:
    ///   - dirfd: Base directory descriptor
    ///   - path: Path relative to `dirfd`
    ///   - flags: Open flags
    /// - Returns: A new `DeviceCapability`
    public static func openAt(
        dirfd: borrowing some DirectoryDescriptor,
        path: String,
        flags: OpenAtFlags = [.readOnly]
    ) throws -> DeviceCapability {
        let deviceFlags = flags.union([.closeOnExec])
        let fd = try dirfd.openFile(path: path, flags: deviceFlags, mode: 0)
        return DeviceCapability(fd)
    }

    // MARK: - Device Information

    /// Returns true if this is a disk device.
    public func isDisk() throws -> Bool {
        let flags = try deviceType()
        return flags.contains(.disk)
    }

    /// Returns true if this is a TTY device.
    public func isTTY() throws -> Bool {
        let flags = try deviceType()
        return flags.contains(.tty)
    }

    /// Returns true if this is a memory device.
    public func isMemoryDevice() throws -> Bool {
        let flags = try deviceType()
        return flags.contains(.mem)
    }

    // MARK: - FileDescriptor Conformance (for seekable devices)

    /// Seek to a position in the device.
    ///
    /// Only valid for seekable devices (like disks).
    public func seek(offset: off_t, whence: Int32) throws -> off_t {
        try self.unsafe { fd in
            while true {
                let pos = Glibc.lseek(fd, offset, whence)
                if pos != -1 { return pos }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }

    /// Read at a specific offset without changing file position.
    ///
    /// Only valid for seekable devices.
    public func pread(count: Int, offset: off_t) throws -> Data {
        guard count >= 0 else {
            throw POSIXError(.EINVAL)
        }

        var buffer = Data(count: count)

        let (n, err): (Int, Int32) = self.unsafe { fd in
            buffer.withUnsafeMutableBytes { ptr -> (Int, Int32) in
                while true {
                    let r = Glibc.pread(fd, ptr.baseAddress, ptr.count, offset)
                    if r >= 0 { return (Int(r), 0) }
                    if errno == EINTR { continue }
                    return (-1, errno)
                }
            }
        }

        if n < 0 { try BSDError.throwErrno(err) }

        buffer.removeSubrange(n..<buffer.count)
        return buffer
    }

    /// Write at a specific offset without changing file position.
    ///
    /// Only valid for seekable devices.
    public func pwrite(_ data: Data, offset: off_t) throws -> Int {
        let (n, err): (Int, Int32) = self.unsafe { fd in
            data.withUnsafeBytes { ptr -> (Int, Int32) in
                while true {
                    let r = Glibc.pwrite(fd, ptr.baseAddress, ptr.count, offset)
                    if r >= 0 { return (Int(r), 0) }
                    if errno == EINTR { continue }
                    return (-1, errno)
                }
            }
        }

        if n < 0 { try BSDError.throwErrno(err) }
        return n
    }

    /// Synchronize device data to stable storage.
    public func sync() throws {
        try self.unsafe { fd in
            while true {
                let r = Glibc.fsync(fd)
                if r == 0 { return }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }
}
