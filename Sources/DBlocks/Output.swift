/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import FreeBSDKit

/// Specifies where DTrace output should be written.
///
/// ## Examples
///
/// ```swift
/// session.work(to: .stdout)
/// session.work(to: .file("/tmp/trace.log"))
/// session.work(to: .null)  // discard
///
/// let buffer = DTraceOutputBuffer()
/// session.work(to: .buffer(buffer))
/// print(buffer.contents)
/// ```
public enum DTraceOutput: Sendable {
    /// Write to standard output.
    case stdout

    /// Write to standard error.
    case stderr

    /// Write to a file at the given path.
    case file(String)

    /// Discard all output.
    case null

    /// Write to a buffer that can be read later.
    case buffer(DTraceOutputBuffer)

    /// Write to an existing file descriptor.
    ///
    /// The descriptor is duplicated internally, so the caller retains ownership
    /// and the original descriptor is not closed.
    case fileDescriptor(Int32)

    /// Creates an output destination from any BSD resource with a file descriptor.
    ///
    /// - Parameter resource: A BSD resource conforming to `BSDResource` with `Int32` raw type.
    /// - Returns: A `.fileDescriptor` output that duplicates the underlying descriptor.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let file = try FileDescriptor.open("/tmp/trace.log", .writeOnly)
    /// session.output(to: .descriptor(file))
    /// ```
    public static func descriptor<D: BSDResource>(
        _ resource: borrowing D
    ) -> DTraceOutput where D.RAWBSD == Int32 {
        resource.unsafe { fd in
            .fileDescriptor(fd)
        }
    }
}

/// A buffer for capturing DTrace output.
public final class DTraceOutputBuffer: @unchecked Sendable {
    private var memoryStream: UnsafeMutablePointer<FILE>?
    // Store pointers so open_memstream can update them
    private var bufferPtr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    private var sizePtr: UnsafeMutablePointer<Int>

    public init() {
        bufferPtr = .allocate(capacity: 1)
        sizePtr = .allocate(capacity: 1)
        bufferPtr.initialize(to: nil)
        sizePtr.initialize(to: 0)
        memoryStream = open_memstream(bufferPtr, sizePtr)
    }

    deinit {
        if let stream = memoryStream {
            fclose(stream)
        }
        if let buf = bufferPtr.pointee {
            free(buf)
        }
        bufferPtr.deallocate()
        sizePtr.deallocate()
    }

    /// The FILE pointer for internal use.
    internal var filePointer: UnsafeMutablePointer<FILE>? {
        memoryStream
    }

    /// Returns the current contents of the buffer as a string.
    public var contents: String {
        guard let stream = memoryStream else { return "" }
        fflush(stream)
        guard let buf = bufferPtr.pointee else { return "" }
        return String(cString: buf)
    }

    /// Clears the buffer.
    public func clear() {
        guard let stream = memoryStream else { return }
        rewind(stream)
        if let buf = bufferPtr.pointee {
            buf.pointee = 0
        }
    }
}

// MARK: - Internal FILE* Access

extension DTraceOutput {
    /// Executes a closure with access to the underlying FILE pointer.
    internal func withFilePointer<T>(_ body: (UnsafeMutablePointer<FILE>) throws -> T) rethrows -> T {
        switch self {
        case .stdout:
            return try body(Glibc.stdout)

        case .stderr:
            return try body(Glibc.stderr)

        case .null:
            guard let devNull = fopen("/dev/null", "w") else {
                return try body(Glibc.stdout)
            }
            defer { fclose(devNull) }
            return try body(devNull)

        case .file(let path):
            guard let file = fopen(path, "a") else {
                return try body(Glibc.stdout)
            }
            defer { fclose(file) }
            return try body(file)

        case .buffer(let buffer):
            guard let fp = buffer.filePointer else {
                return try body(Glibc.stdout)
            }
            return try body(fp)

        case .fileDescriptor(let fd):
            // dup() so fclose() doesn't close the caller's descriptor
            let dupFd = dup(fd)
            guard dupFd >= 0 else {
                return try body(Glibc.stdout)
            }
            guard let file = fdopen(dupFd, "a") else {
                close(dupFd)
                return try body(Glibc.stdout)
            }
            defer { fclose(file) }  // closes dupFd, not original
            return try body(file)
        }
    }
}
