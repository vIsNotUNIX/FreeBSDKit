/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// Wraps a value type in reference semantics.
public class BSDBox<T> {
    private var value: T?
    public init(_ value: T) {
        self.value = value
    }
    public func empty() -> T? {
        defer { value = nil}
        return value
    }
    
    public func set(new: T) {
        self.value = new
    }
}