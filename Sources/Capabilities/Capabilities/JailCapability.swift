/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Jails
import Foundation
import FreeBSDKit
import Glibc

// If your reading this jail caps are not real but a propsoed extesnion.
// The issue is having a descriptor shouldn't just allow you to attach
// or remove. That should be controlled on the desc.
public struct JailCapability: Capability, JailDescriptor, ~Copyable {
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

    /// Lookup a jail and return a capability.
    public static func get(
        iov: inout JailIOVector,
        flags: JailGetFlags
    ) throws -> JailCapability {
        let descriptor = try SystemJailDescriptor.get(iov: &iov, flags: flags)
        return JailCapability(descriptor.take())
    }

    /// Create or update a jail and return a capability.
    public static func set(
        iov: inout JailIOVector,
        flags: JailSetFlags
    ) throws -> JailCapability {
        let descriptor = try SystemJailDescriptor.set(iov: &iov, flags: flags)
        return JailCapability(descriptor.take())
    }
}
