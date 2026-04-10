/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import CExterr

// MARK: - Extended error info

/// FreeBSD's extended error info subsystem (FreeBSD 14+).
///
/// Some recent FreeBSD syscalls attach a per-thread "extended error" record
/// to a failure: a category, a kernel-supplied numeric ID, and a short
/// human-readable string describing what specifically went wrong inside the
/// kernel. This is in addition to the usual `errno`, which is necessarily
/// coarse.
///
/// `ExtendedError` exposes the most recent extended error message attached
/// to the calling thread via `uexterr_gettext(3)`. The record is cleared
/// (or replaced) by the next syscall that participates in the subsystem,
/// so it should be retrieved immediately after the failing call.
public enum ExtendedError {

    /// Default buffer size for `currentMessage()`. The kernel-supplied
    /// strings are short — 256 bytes is comfortably enough.
    public static let defaultBufferSize = 256

    /// Fetch the human-readable extended error text attached to the
    /// current thread, if any.
    ///
    /// Call this immediately after a failing syscall — subsequent calls
    /// that participate in the extended-error subsystem will overwrite the
    /// per-thread record.
    ///
    /// - Parameter bufferSize: Size of the temporary buffer to use.
    /// - Returns: The extended error string, or `nil` if no extended error
    ///   is attached to the calling thread.
    public static func currentMessage(bufferSize: Int = defaultBufferSize) -> String? {
        guard bufferSize > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: bufferSize)
        let r = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            CExterr.uexterr_gettext(ptr.baseAddress, ptr.count)
        }
        if r != 0 {
            return nil
        }
        // The buffer is null-terminated by the kernel; an empty string
        // means "no extended error attached".
        let message = String(cString: buf)
        return message.isEmpty ? nil : message
    }
}

// MARK: - BSDError integration

public extension BSDError {

    /// Combine this error with the current thread's extended-error message
    /// (if any) into a single human-readable string.
    ///
    /// On FreeBSD 14+ this surfaces the kernel-supplied detail line that
    /// `uexterr_gettext(3)` returns; on older systems or for syscalls that
    /// do not participate in the extended-error subsystem, the result is
    /// just the standard `BSDError` description.
    var detailedDescription: String {
        if let extra = ExtendedError.currentMessage() {
            return "\(description): \(extra)"
        }
        return description
    }
}
