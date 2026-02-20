/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// Forward declare sysctlbyname from libc
@_silgen_name("sysctlbyname")
private func sysctlbyname(
    _ name: UnsafePointer<CChar>,
    _ oldp: UnsafeMutableRawPointer?,
    _ oldlenp: UnsafeMutablePointer<Int>,
    _ newp: UnsafeRawPointer?,
    _ newlen: Int
) -> Int32

/// Utilities for querying socket size limits from the operating system.
public enum SocketLimits {

    /// Returns the maximum SEQPACKET message size from the kernel.
    ///
    /// Queries `net.local.seqpacket.maxseqpacket` sysctl to get the maximum
    /// message size for Unix-domain SEQPACKET sockets. Falls back to a
    /// conservative 64KB if the query fails.
    ///
    /// - Returns: Maximum message size in bytes (typically 65536)
    public static func maxSeqpacketSize() -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size

        let name = "net.local.seqpacket.maxseqpacket"
        let result = name.withCString { namePtr in
            sysctlbyname(namePtr, &value, &size, nil as UnsafeRawPointer?, 0)
        }

        guard result == 0 else {
            // Fallback to conservative default if sysctl fails
            return 65536
        }

        return Int(value)
    }

    /// Returns the maximum datagram size from the kernel.
    ///
    /// Queries `net.local.dgram.maxdgram` sysctl to get the maximum
    /// message size for Unix-domain DATAGRAM sockets.
    ///
    /// - Returns: Maximum datagram size in bytes (typically 8192)
    public static func maxDatagramSize() -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size

        let name = "net.local.dgram.maxdgram"
        let result = name.withCString { namePtr in
            sysctlbyname(namePtr, &value, &size, nil as UnsafeRawPointer?, 0)
        }

        guard result == 0 else {
            // Fallback to conservative default if sysctl fails
            return 8192
        }

        return Int(value)
    }
}
