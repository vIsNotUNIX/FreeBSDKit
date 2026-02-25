/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Glibc
import Foundation
import FreeBSDKit

// MARK: - DescriptorKind Wire Format
//
// Wire values for descriptor kinds in FPC trailer:
//
// | Value | Kind              |
// |-------|-------------------|
// | 0     | unknown           |
// | 1     | file              |
// | 2     | directory         |
// | 3     | process           |
// | 4     | kqueue            |
// | 5     | socket            |
// | 6     | pipe              |
// | 7     | jail (non-owning) |
// | 8     | jail (owning)     |
// | 9     | shm               |
// | 10    | event             |
// | 255   | OOL payload       |

extension DescriptorKind {
    /// Special wire value indicating an out-of-line payload descriptor.
    ///
    /// When a message's payload exceeds the inline limit, it's sent via shared memory.
    /// The shm descriptor is placed at index 0 and marked with this value (255).
    public static let oolPayloadWireValue: UInt8 = 255

    /// Encodes this descriptor kind to a wire format byte.
    public var wireValue: UInt8 {
        switch self {
        case .file: return 1
        case .directory: return 2
        case .process: return 3
        case .kqueue: return 4
        case .socket: return 5
        case .pipe: return 6
        case .jail(owning: false): return 7
        case .jail(owning: true): return 8
        case .shm: return 9
        case .event: return 10
        case .unknown: return 0
        }
    }

    /// Decodes a descriptor kind from a wire format byte.
    public static func fromWireValue(_ value: UInt8) -> DescriptorKind {
        switch value {
        case 1: return .file
        case 2: return .directory
        case 3: return .process
        case 4: return .kqueue
        case 5: return .socket
        case 6: return .pipe
        case 7: return .jail(owning: false)
        case 8: return .jail(owning: true)
        case 9: return .shm
        case 10: return .event
        default: return .unknown
        }
    }
}