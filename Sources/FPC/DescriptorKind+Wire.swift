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
// | 3     | device            |
// | 4     | process           |
// | 5     | kqueue            |
// | 6     | socket            |
// | 7     | pipe              |
// | 8     | jail (non-owning) |
// | 9     | jail (owning)     |
// | 10    | shm               |
// | 11    | event             |
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
        case .device: return 3
        case .process: return 4
        case .kqueue: return 5
        case .socket: return 6
        case .pipe: return 7
        case .jail(owning: false): return 8
        case .jail(owning: true): return 9
        case .shm: return 10
        case .event: return 11
        case .unknown: return 0
        }
    }

    /// Decodes a descriptor kind from a wire format byte.
    public static func fromWireValue(_ value: UInt8) -> DescriptorKind {
        switch value {
        case 1: return .file
        case 2: return .directory
        case 3: return .device
        case 4: return .process
        case 5: return .kqueue
        case 6: return .socket
        case 7: return .pipe
        case 8: return .jail(owning: false)
        case 9: return .jail(owning: true)
        case 10: return .shm
        case 11: return .event
        default: return .unknown
        }
    }
}