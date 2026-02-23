/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Capabilities
@testable import MacLabel
import Glibc

/// Test helper functions for MacLabel tests.
enum TestHelpers {
    /// Loads a configuration from a file path for testing purposes.
    ///
    /// This is a convenience wrapper that opens the file, creates a FileCapability,
    /// and loads the configuration. It's designed for test use only.
    ///
    /// - Parameter path: Path to configuration file
    /// - Returns: Loaded configuration
    /// - Throws: LabelError if file cannot be loaded
    static func loadConfiguration(from path: String) throws -> FileLabelConfiguration {
        // Validate path before attempting to open
        guard !path.isEmpty else {
            throw LabelError.invalidConfiguration("Invalid configuration file path: path cannot be empty")
        }

        guard !path.contains("\0") else {
            throw LabelError.invalidConfiguration("Invalid configuration file path: path contains null byte")
        }

        let rawFd = path.withCString { cPath in
            open(cPath, O_RDONLY | O_CLOEXEC)
        }

        guard rawFd >= 0 else {
            throw LabelError.invalidConfiguration("Cannot open test config file: \(String(cString: strerror(errno)))")
        }

        let capability = FileCapability(rawFd)

        do {
            let config = try FileLabelConfiguration.load(from: capability)
            capability.close()
            return config
        } catch {
            capability.close()
            throw error
        }
    }
}
