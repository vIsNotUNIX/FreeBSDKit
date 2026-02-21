/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Descriptors
import Glibc
import Foundation
import FreeBSDKit

extension DescriptorKind {
    /// Special wire value indicating an out-of-line payload descriptor.
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