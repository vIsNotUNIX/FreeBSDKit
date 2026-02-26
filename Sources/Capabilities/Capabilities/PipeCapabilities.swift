/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit
import Descriptors

public struct PipePair: ~Copyable {
    public var read: PipeReadCapability
    public var write: PipeWriteCapability

    public static func createPair() throws -> Self {
        var fds: [Int32] = [ -1, -1 ]
        let res = Glibc.pipe(&fds)
        guard res == 0 else {
            try BSDError.throwErrno(errno)
        }
        return PipePair(
            read: PipeReadCapability(fds[0]), 
            write: PipeWriteCapability(fds[1])
        )
    }
}

/// The read end of a pipe, with capability support.
public struct PipeReadCapability: Capability, PipeReadDescriptor, ~Copyable {
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

    public func unsafe<R>(_ block: (RAWBSD) throws -> R ) rethrows -> R where R: ~Copyable {
        try handle.unsafe(block)
    }
}

/// The write end of a pipe, with capability support.
public struct PipeWriteCapability: Capability, PipeWriteDescriptor, ~Copyable {
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

    public func unsafe<R>(_ block: (RAWBSD) throws -> R ) rethrows -> R where R: ~Copyable {
        try handle.unsafe(block)
    }
}
