/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/// Errors that can occur during DTrace operations.
public enum DTraceCoreError: Error, Sendable {
    /// Failed to open DTrace handle.
    case openFailed(code: Int32, message: String)

    /// Failed to compile D program.
    case compileFailed(message: String)

    /// Failed to execute D program.
    case execFailed(message: String)

    /// Failed to start tracing.
    case goFailed(message: String)

    /// Failed to stop tracing.
    case stopFailed(message: String)

    /// Error during work loop.
    case workFailed(message: String)

    /// Failed to set option.
    case setOptFailed(option: String, message: String)

    /// Failed to get option.
    case getOptFailed(option: String, message: String)

    /// Failed to iterate probes.
    case probeIterFailed(message: String)

    /// Failed to register handler.
    case handlerFailed(message: String)

    /// Aggregation operation failed.
    case aggregateFailed(message: String)

    /// Failed to grab/attach to process.
    case procGrabFailed(pid: Int32, message: String)

    /// Failed to consume trace data.
    case consumeFailed(message: String)

    /// Handle is no longer valid (already closed or consumed).
    case invalidHandle
}
