/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - Inotify Descriptor Protocol

/// Capability interface for inotify descriptors.
public protocol InotifyDescriptor: Descriptor, ~Copyable {

    func addWatch(path: String, mask: InotifyEventMask) throws -> InotifyWatch
    func addWatch<D: Descriptor>
        (directory: D, path: String, mask: InotifyEventMask) throws -> InotifyWatch
    func removeWatch(_ watch: InotifyWatch) throws
    func readEvents(maxBytes: Int) throws -> [InotifyEvent]
}

public extension InotifyDescriptor where Self: ~Copyable {

    func addWatch(
        path: String,
        mask: InotifyEventMask
    ) throws -> InotifyWatch {

        try self.unsafe { fd in
            let wd = path.withCString {
                Glibc.inotify_add_watch(fd, $0, mask.rawBSD)
            }
            guard wd >= 0 else {
                try BSDError.throwErrno(errno)
            }
            return InotifyWatch(rawBSD: wd)
        }
    }

    func addWatch<D: Descriptor>(
        directory: D,
        path: String,
        mask: InotifyEventMask
    ) throws -> InotifyWatch {

        try self.unsafe { inotifyFD in
            try directory.unsafe { dirFD in
                let wd = path.withCString {
                    Glibc.inotify_add_watch_at(
                        inotifyFD,
                        dirFD,
                        $0,
                        mask.rawBSD
                    )
                }

                guard wd >= 0 else {
                    try BSDError.throwErrno(errno)
                }

                return InotifyWatch(rawBSD: wd)
            }
        }
    }

    func removeWatch(_ watch: InotifyWatch) throws {
        try self.unsafe { fd in
            guard Glibc.inotify_rm_watch(fd, watch.rawBSD) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func readEvents(maxBytes: Int = 4096) throws -> [InotifyEvent] {

        try self.unsafe { fd in
            var buffer = [UInt8](repeating: 0, count: maxBytes)

            // Retry on EINTR, return empty on EAGAIN/EWOULDBLOCK
            let bytesRead: Int = try buffer.withUnsafeMutableBytes { bufPtr in
                while true {
                    let result = Glibc.read(fd, bufPtr.baseAddress, maxBytes)
                    if result >= 0 {
                        return Int(result)
                    }

                    let err = errno
                    if err == EINTR {
                        continue
                    }
                    if err == EAGAIN || err == EWOULDBLOCK {
                        return 0  // No events available (nonblocking mode)
                    }
                    try BSDError.throwErrno(err)
                }
            }

            var events: [InotifyEvent] = []
            var offset = 0

            buffer.withUnsafeBytes { ptr in
                while offset < bytesRead {
                    // Bounds check: ensure we can read inotify_event header
                    guard offset + MemoryLayout<inotify_event>.size <= bytesRead else {
                        break  // Truncated read, stop parsing
                    }

                    let base = ptr.baseAddress!.advanced(by: offset)
                    let ev = base
                        .assumingMemoryBound(to: inotify_event.self)
                        .pointee

                    // Bounds check: ensure we can read the full event including name
                    guard offset + MemoryLayout<inotify_event>.size + Int(ev.len) <= bytesRead else {
                        break  // Truncated name, stop parsing
                    }

                    let namePtr = base
                        .advanced(by: MemoryLayout<inotify_event>.size)
                        .assumingMemoryBound(to: UInt8.self)

                    // Safe string construction via copying conversion
                    let name: String? = (ev.len > 1)
                        ? String(
                            decoding: UnsafeBufferPointer(
                                start: namePtr,
                                count: Int(ev.len) - 1  // Exclude trailing NUL
                            ),
                            as: UTF8.self
                          )
                        : nil

                    events.append(
                        InotifyEvent(
                            watch: InotifyWatch(rawBSD: ev.wd),
                            mask: InotifyEventMask(rawValue: ev.mask),
                            cookie: ev.cookie,
                            name: name
                        )
                    )

                    offset += MemoryLayout<inotify_event>.size + Int(ev.len)
                }
            }

            return events
        }
    }
}

// MARK: - Supporting Value Types

public struct InotifyWatch: BSDValue, Hashable, Sendable {
    public typealias RAWBSD = Int32
    public let rawBSD: Int32
}

public struct InotifyEventMask: OptionSet, BSDValue, Sendable {

    public typealias RAWBSD = UInt32
    public let rawValue: UInt32
    public var rawBSD: UInt32 { rawValue }

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    @inline(__always)
    private static func flag(_ v: Int32) -> UInt32 {
        UInt32(bitPattern: v)
    }

    // MARK: - Event Flags

    public static let access        = Self(rawValue: flag(IN_ACCESS))
    public static let attrib        = Self(rawValue: flag(IN_ATTRIB))
    public static let modify        = Self(rawValue: flag(IN_MODIFY))
    public static let closeWrite    = Self(rawValue: flag(IN_CLOSE_WRITE))
    public static let closeNoWrite  = Self(rawValue: flag(IN_CLOSE_NOWRITE))
    public static let open          = Self(rawValue: flag(IN_OPEN))
    public static let movedFrom     = Self(rawValue: flag(IN_MOVED_FROM))
    public static let movedTo       = Self(rawValue: flag(IN_MOVED_TO))
    public static let create        = Self(rawValue: flag(IN_CREATE))
    public static let delete        = Self(rawValue: flag(IN_DELETE))
    public static let deleteSelf    = Self(rawValue: flag(IN_DELETE_SELF))
    public static let moveSelf      = Self(rawValue: flag(IN_MOVE_SELF))

    // MARK: - Metadata Flags

    public static let ignored       = Self(rawValue: flag(IN_IGNORED))
    public static let isDir         = Self(rawValue: flag(IN_ISDIR))
    public static let queueOverflow = Self(rawValue: flag(IN_Q_OVERFLOW))
    public static let unmount       = Self(rawValue: flag(IN_UNMOUNT))

    // MARK: - Watch Creation Flags

    /// Only watch if path is a directory
    public static let onlyDir       = Self(rawValue: flag(IN_ONLYDIR))
    /// Don't follow symbolic links
    public static let dontFollow    = Self(rawValue: flag(IN_DONT_FOLLOW))
    /// Currently has no effect on FreeBSD
    public static let exclUnlink    = Self(rawValue: flag(IN_EXCL_UNLINK))
    /// Fail if watch already exists
    public static let maskCreate    = Self(rawValue: flag(IN_MASK_CREATE))
    /// OR with existing watch mask instead of replacing
    public static let maskAdd       = Self(rawValue: flag(IN_MASK_ADD))
    /// Remove watch after first event (0x80000000 exceeds Int32.max)
    public static let oneshot       = Self(rawValue: 0x8000_0000 as UInt32)
}

public struct InotifyEvent: Sendable {
    public let watch: InotifyWatch
    public let mask: InotifyEventMask
    public let cookie: UInt32
    public let name: String?
}