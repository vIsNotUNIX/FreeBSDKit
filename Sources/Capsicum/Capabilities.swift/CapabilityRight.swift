import CCapsicum

/// Individual Capability Rights.
public enum CapabilityRight: CaseIterable {
    case read
    case write
    case seek

    /// Bridges a capability
    @inline(__always)
    var bridged: ccapsicum_right_bridge {
        switch self {
        case .read:  return CCAP_RIGHT_READ
        case .write: return CCAP_RIGHT_WRITE
        case .seek:  return CCAP_RIGHT_SEEK
        }
    }
}