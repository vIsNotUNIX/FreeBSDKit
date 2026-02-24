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
// Wire values for descriptor kinds in BPC trailer:
//
// | Value | Kind              |
// |-------|-------------------|
// | 0     | unknown           |
// | 1     | file              |
// | 2     | process           |
// | 3     | kqueue            |
// | 4     | socket            |
// | 5     | pipe              |
// | 6     | jail (non-owning) |
// | 7     | jail (owning)     |
// | 8     | shm               |
// | 9     | event             |
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
        case .process: return 2
        case .kqueue: return 3
        case .socket: return 4
        case .pipe: return 5
        case .jail(owning: false): return 6
        case .jail(owning: true): return 7
        case .shm: return 8
        case .event: return 9
        case .unknown: return 0
        }
    }

    /// Decodes a descriptor kind from a wire format byte.
    public static func fromWireValue(_ value: UInt8) -> DescriptorKind {
        switch value {
        case 1: return .file
        case 2: return .process
        case 3: return .kqueue
        case 4: return .socket
        case 5: return .pipe
        case 6: return .jail(owning: false)
        case 7: return .jail(owning: true)
        case 8: return .shm
        case 9: return .event
        default: return .unknown
        }
    }
}