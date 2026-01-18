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
    func addWatch(directoryFD: Int32, path: String, mask: InotifyEventMask) throws -> InotifyWatch
    func removeWatch(_ watch: InotifyWatch) throws
    func readEvents(maxBytes: Int) throws -> [InotifyEvent]
}

// MARK: - Default Implementations

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
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return InotifyWatch(rawBSD: wd)
        }
    }

    func addWatch(
        directoryFD: Int32,
        path: String,
        mask: InotifyEventMask
    ) throws -> InotifyWatch {

        try self.unsafe { fd in
            let wd = path.withCString {
                Glibc.inotify_add_watch_at(fd, directoryFD, $0, mask.rawBSD)
            }
            guard wd >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return InotifyWatch(rawBSD: wd)
        }
    }

    func removeWatch(_ watch: InotifyWatch) throws {
        try self.unsafe { fd in
            guard Glibc.inotify_rm_watch(fd, watch.rawBSD) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    func readEvents(maxBytes: Int = 4096) throws -> [InotifyEvent] {

        try self.unsafe { fd in
            var buffer = [UInt8](repeating: 0, count: maxBytes)

            let n = buffer.withUnsafeMutableBytes {
                Glibc.read(fd, $0.baseAddress, maxBytes)
            }

            guard n >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }

            var events: [InotifyEvent] = []
            var offset = 0

            buffer.withUnsafeBytes { ptr in
                while offset < n {
                    let base = ptr.baseAddress!.advanced(by: offset)
                    let ev = base
                        .assumingMemoryBound(to: inotify_event.self)
                        .pointee

                    let namePtr = base
                        .advanced(by: MemoryLayout<inotify_event>.size)
                        .assumingMemoryBound(to: UInt8.self)

                    let name =
                        ev.len > 0
                        ? String(
                            bytesNoCopy: UnsafeMutableRawPointer(mutating: namePtr),
                            length: Int(ev.len) - 1,
                            encoding: .utf8,
                            freeWhenDone: false
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

    public static let ignored       = Self(rawValue: flag(IN_IGNORED))
    public static let isDir         = Self(rawValue: flag(IN_ISDIR))
    public static let queueOverflow = Self(rawValue: flag(IN_Q_OVERFLOW))
    public static let unmount       = Self(rawValue: flag(IN_UNMOUNT))
}

public struct InotifyEvent: Sendable {
    public let watch: InotifyWatch
    public let mask: InotifyEventMask
    public let cookie: UInt32
    public let name: String?
}