/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

// MARK: - Base Opaque Descriptor

/// Type-erased, reference-counted BSD file descriptor.
///
/// This class provides:
/// - Thread-safe access
/// - Reference-counted lifetime
/// - Deterministic `close(2)` on deinit
///
/// It intentionally has **no capability semantics**.
/// Those are layered in subclasses.
open class OpaqueDescriptorRef: CustomDebugStringConvertible, @unchecked Sendable {

    private var fd: Int32?
    private var _kind: DescriptorKind = .unknown
    private let lock = NSLock()

    public init(_ value: Int32) {
        self.fd = value
    }

    public init(_ fd: Int32, kind: DescriptorKind) {
        self.fd = fd
        self._kind = kind
    }

    public var kind: DescriptorKind {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _kind
        }
        set {
            lock.lock()
            _kind = newValue
            lock.unlock()
        }
    }

    /// Return the underlying BSD descriptor, if still valid.
    ///
    /// This is intentionally **optional** to reflect lifetime.
    public func toBSDValue() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        return fd
    }

    /// Transfers ownership of the file descriptor to the caller.
    ///
    /// After calling this method, the descriptor will not be closed on deinit.
    /// The caller is responsible for closing the returned file descriptor.
    ///
    /// - Returns: The file descriptor, or `nil` if already taken or closed
    public func take() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        guard let descriptor = fd else { return nil }
        fd = nil
        return descriptor
    }

    deinit {
        lock.lock()
        if let desc = fd {
            Glibc.close(desc)
            fd = nil
        }
        lock.unlock()
    }

    open var debugDescription: String {
        lock.lock()
        let desc = fd ?? -1
        let kind = _kind
        lock.unlock()
        return "OpaqueDescriptorRef(kind: \(kind), fd: \(desc))"
    }
}