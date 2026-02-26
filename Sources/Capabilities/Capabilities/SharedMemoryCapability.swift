/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import Descriptors

/// A shared memory capability descriptor.
public struct SharedMemoryCapability: Capability, SharedMemoryDescriptor, ~Copyable {
    private var handle: RawCapabilityHandle

    public init(_ raw: Int32) {
        self.handle = RawCapabilityHandle(raw)
    }

    public consuming func close() {
        handle.close()
    }

    public consuming func take() -> Int32 {
        handle.take()
    }

    public func unsafe<R>(_ block: (Int32) throws -> R) rethrows -> R
        where R: ~Copyable {
        try handle.unsafe(block)
    }
}
