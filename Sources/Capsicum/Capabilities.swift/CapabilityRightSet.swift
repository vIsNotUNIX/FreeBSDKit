import CCapsicum

/// CapabilityRightSet
public struct CapabilityRightSet {
    private var rights: cap_rights_t

    /// Initilizes an empty CapabilityRightSet
    public init() {
        var r = cap_rights_t()
        ccapsicum_rights_init(&r)
        self.rights = r
    }

    /// Initialize from a cap_rights_t.
    public init(from rights: cap_rights_t) {
        self.rights = rights
    }
    /// Initialize from an array of `Capability`.
    public init(rights: [CapabilityRight]) {
        self.rights = {
            var r = cap_rights_t()
            ccapsicum_rights_init(&r)
            for right in rights {
                switch right {
                case .read:
                    ccaspsicum_cap_set(&r, right.bridged)
                case .write:
                    ccaspsicum_cap_set(&r, right.bridged)
                case .seek:
                    ccaspsicum_cap_set(&r, right.bridged)
                }
            }
            return r
        }()
    }

    public mutating func add(capability: CapabilityRight) {
            switch capability {
            case .read:
                ccaspsicum_cap_set(&rights, capability.bridged)
            case .write:
                ccaspsicum_cap_set(&rights, capability.bridged)
            case .seek:
                ccaspsicum_cap_set(&rights, capability.bridged)
            }
    }

    public mutating func add(capabilites: [CapabilityRight]) {
        for cap in capabilites {
            switch cap {
            case .read:
                ccaspsicum_cap_set(&rights, cap.bridged)
            case .write:
                ccaspsicum_cap_set(&rights, cap.bridged)
            case .seek:
                ccaspsicum_cap_set(&rights, cap.bridged)
            }
        }
    }

    public mutating func clear(capabilites: [CapabilityRight]) {
        for cap in capabilites {
            switch cap {
            case .read:
                ccap_rights_clear(&rights, cap.bridged)
            case .write:
                ccap_rights_clear(&rights, cap.bridged)
            case .seek:                
                ccap_rights_clear(&rights, cap.bridged)
            }  
        }
    }

    public mutating func contains(capability: CapabilityRight) -> Bool {
        switch capability {
        case .read:
            return ccapsicum_right_is_set(&rights, capability.bridged)
        case .write:
            return ccapsicum_right_is_set(&rights, capability.bridged)
        case .seek:
            return ccapsicum_right_is_set(&rights, capability.bridged)
        }
    }

    public mutating func contains(right other: CapabilityRightSet) -> Bool {
        var contains = false
        withUnsafePointer(to: other.rights) { otherRights in
            contains = ccap_rights_contains(&rights, otherRights)
        }
        return contains
    }

    /// Returns a new merged `CapabilityRightSet`` instance.
    public mutating func merge(with other: CapabilityRightSet) -> CapabilityRightSet {
        withUnsafePointer(to: other.rights) { srcPtr in
            _ = ccapsicum_cap_rights_merge(&rights, srcPtr)
        }
        return other
    }
    public mutating func remove(matching right: CapabilityRightSet) -> CapabilityRightSet {
        withUnsafePointer(to: right.rights) { srcPtr in
            _ = ccap_rights_remove(&rights, srcPtr)
        }
        return right
    }

    public mutating func valid() -> Bool {
        return ccap_rights_valid(&rights)
    }

    public func asCRights() -> cap_rights_t {
        return rights
    }

    public mutating func limit(fd: Int32) -> Bool {
        ccapsicum_cap_limit(fd, &rights) == 0
    }
}