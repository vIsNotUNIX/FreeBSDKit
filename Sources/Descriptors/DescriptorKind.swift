/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

public enum DescriptorKind: Sendable, Equatable, Hashable {
    case file
    case directory
    case device
    case process
    case kqueue
    case socket
    case pipe
    case jail(owning: Bool)
    case shm
    case event
    case unknown
}