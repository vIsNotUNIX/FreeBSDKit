/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CDTrace

/// A compiled D program.
///
/// D programs are compiled from source using `DTraceHandle.compile(_:flags:)`
/// and then executed with `DTraceHandle.exec(_:)`.
///
/// This is a move-only type. The program is owned by the DTrace handle that
/// compiled it and will be freed when the handle is closed.
public struct DTraceProgram: ~Copyable {
    private let program: OpaquePointer

    internal init(program: OpaquePointer) {
        self.program = program
    }

    /// Returns the underlying program pointer for advanced usage.
    ///
    /// - Warning: The pointer is only valid for the lifetime of the
    ///   `DTraceHandle` that compiled this program.
    public func unsafeProgram() -> OpaquePointer {
        program
    }
}
