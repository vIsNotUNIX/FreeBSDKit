/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import CDeviceIoctl
import Foundation
import FreeBSDKit

// MARK: - Device Type Flags

/// Device type flags returned by `FIODTYPE` ioctl.
///
/// These flags describe characteristics of the device.
public struct DeviceTypeFlags: OptionSet, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// Device supports disk-like ioctls.
    public static let disk = DeviceTypeFlags(rawValue: CDEV_D_DISK)

    /// Device is a TTY.
    public static let tty = DeviceTypeFlags(rawValue: CDEV_D_TTY)

    /// Device supports memory mapping.
    public static let mem = DeviceTypeFlags(rawValue: CDEV_D_MEM)
}

// MARK: - DeviceDescriptor

/// A descriptor representing an open device file.
///
/// `DeviceDescriptor` provides device-specific operations beyond basic read/write,
/// including `ioctl()` for device control and query operations.
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
/// let device = try DeviceCapability.open(path: "/dev/da0")
///
/// // Query device characteristics
/// let mediaSize = try device.mediaSize()
/// let sectorSize = try device.sectorSize()
///
/// // Perform custom ioctl
/// var value: Int32 = 0
/// try device.ioctl(FIONREAD, &value)
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
public protocol DeviceDescriptor: ReadWriteDescriptor, ~Copyable {

    // MARK: - ioctl Operations

    /// Perform a device ioctl with no argument.
    ///
    /// - Parameter request: The ioctl request code
    func ioctl(_ request: UInt) throws

    /// Perform a device ioctl with an input/output argument.
    ///
    /// - Parameters:
    ///   - request: The ioctl request code
    ///   - arg: Pointer to the argument (input, output, or both depending on request)
    func ioctl<T>(_ request: UInt, _ arg: UnsafeMutablePointer<T>) throws

    // MARK: - Common Device Queries

    /// Get the number of bytes immediately available for reading.
    ///
    /// Uses `FIONREAD` ioctl.
    func bytesAvailable() throws -> Int

    /// Get the number of bytes in the send queue.
    ///
    /// Uses `FIONWRITE` ioctl.
    func bytesInSendQueue() throws -> Int

    /// Get free space in the send queue.
    ///
    /// Uses `FIONSPACE` ioctl.
    func sendQueueSpace() throws -> Int

    /// Get device type flags.
    ///
    /// Uses `FIODTYPE` ioctl.
    func deviceType() throws -> DeviceTypeFlags

    /// Get the device name.
    ///
    /// Uses `FIODGNAME` ioctl.
    func deviceName() throws -> String

    // MARK: - Async/Non-blocking Control

    /// Enable or disable non-blocking I/O.
    ///
    /// Uses `FIONBIO` ioctl. This is equivalent to setting `O_NONBLOCK`
    /// via `fcntl()` but may be preferred for device-specific reasons.
    func setNonBlocking(_ enabled: Bool) throws

    /// Enable or disable async I/O signal delivery.
    ///
    /// Uses `FIOASYNC` ioctl. When enabled, `SIGIO` is sent when I/O
    /// becomes possible.
    func setAsyncIO(_ enabled: Bool) throws

    // MARK: - Disk Device Operations

    /// Get the sector size of a disk device.
    ///
    /// Uses `DIOCGSECTORSIZE` ioctl. Only valid for disk devices.
    func sectorSize() throws -> UInt32

    /// Get the media size in bytes of a disk device.
    ///
    /// Uses `DIOCGMEDIASIZE` ioctl. Only valid for disk devices.
    func mediaSize() throws -> off_t

    /// Flush the write cache of a disk device.
    ///
    /// Uses `DIOCGFLUSH` ioctl. Only valid for disk devices.
    func flushCache() throws

    /// Get the disk identifier string.
    ///
    /// Uses `DIOCGIDENT` ioctl. Only valid for disk devices.
    func diskIdentifier() throws -> String
}

// MARK: - Default Implementations

public extension DeviceDescriptor where Self: ~Copyable {

    func ioctl(_ request: UInt) throws {
        try self.unsafe { fd in
            while true {
                let result = cdev_ioctl_void(fd, request)
                if result == 0 { return }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }

    func ioctl<T>(_ request: UInt, _ arg: UnsafeMutablePointer<T>) throws {
        try self.unsafe { fd in
            while true {
                let result = cdev_ioctl_ptr(fd, request, arg)
                if result == 0 { return }
                if errno == EINTR { continue }
                try BSDError.throwErrno(errno)
            }
        }
    }

    func bytesAvailable() throws -> Int {
        var value: Int32 = 0
        try ioctl(CDEV_FIONREAD, &value)
        return Int(value)
    }

    func bytesInSendQueue() throws -> Int {
        var value: Int32 = 0
        try ioctl(CDEV_FIONWRITE, &value)
        return Int(value)
    }

    func sendQueueSpace() throws -> Int {
        var value: Int32 = 0
        try ioctl(CDEV_FIONSPACE, &value)
        return Int(value)
    }

    func deviceType() throws -> DeviceTypeFlags {
        var value: Int32 = 0
        try ioctl(CDEV_FIODTYPE, &value)
        return DeviceTypeFlags(rawValue: value)
    }

    func deviceName() throws -> String {
        // FIODGNAME uses struct fiodgname_arg { int len; char *buf; }
        // We need to handle this specially
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        try buffer.withUnsafeMutableBufferPointer { ptr in
            var arg = fiodgname_arg()
            arg.len = Int32(ptr.count)
            arg.buf = UnsafeMutableRawPointer(ptr.baseAddress)
            try ioctl(CDEV_FIODGNAME, &arg)
        }
        return buffer.withUnsafeBytes { ptr in
            let utf8 = ptr.bindMemory(to: UInt8.self)
            let length = utf8.firstIndex(of: 0) ?? utf8.count
            return String(decoding: utf8.prefix(length), as: UTF8.self)
        }
    }

    func setNonBlocking(_ enabled: Bool) throws {
        var value: Int32 = enabled ? 1 : 0
        try ioctl(CDEV_FIONBIO, &value)
    }

    func setAsyncIO(_ enabled: Bool) throws {
        var value: Int32 = enabled ? 1 : 0
        try ioctl(CDEV_FIOASYNC, &value)
    }

    func sectorSize() throws -> UInt32 {
        var value: UInt32 = 0
        try ioctl(CDEV_DIOCGSECTORSIZE, &value)
        return value
    }

    func mediaSize() throws -> off_t {
        var value: off_t = 0
        try ioctl(CDEV_DIOCGMEDIASIZE, &value)
        return value
    }

    func flushCache() throws {
        try ioctl(CDEV_DIOCGFLUSH)
    }

    func diskIdentifier() throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(CDEV_DISK_IDENT_SIZE))
        try buffer.withUnsafeMutableBufferPointer { ptr in
            // DIOCGIDENT takes char[DISK_IDENT_SIZE] directly
            try self.unsafe { fd in
                while true {
                    let result = cdev_ioctl_ptr(fd, CDEV_DIOCGIDENT, ptr.baseAddress)
                    if result == 0 { return }
                    if errno == EINTR { continue }
                    try BSDError.throwErrno(errno)
                }
            }
        }
        return buffer.withUnsafeBytes { ptr in
            let utf8 = ptr.bindMemory(to: UInt8.self)
            let length = utf8.firstIndex(of: 0) ?? utf8.count
            return String(decoding: utf8.prefix(length), as: UTF8.self)
        }
    }
}
