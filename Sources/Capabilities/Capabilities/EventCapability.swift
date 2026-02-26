/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Descriptors
import Foundation
import FreeBSDKit


public struct EventCapability: Capability, EventDescriptor, ~Copyable {
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