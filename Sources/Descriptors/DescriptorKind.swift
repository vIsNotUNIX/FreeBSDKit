import Glibc
import Foundation
import FreeBSDKit

public enum DescriptorKind: Sendable {
    case file
    case process
    case kqueue
    case socket
    case pipe
    case shm
    case event
    case unknown
}