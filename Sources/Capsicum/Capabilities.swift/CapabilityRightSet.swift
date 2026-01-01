import CCapsicum

/// CapabilityRightSet
public struct CapabilityRightSet {
    private var rights: cap_rights_t

    /// Initilizes an empty CapabilityRightSet
    public init() {
        var rights = cap_rights_t()
        ccapsicum_rights_init(&rights)
        self.rights = rights
    }

    /// Initialize from a cap_rights_t.
    public init(rights: cap_rights_t) {
        self.rights = rights
    }
    /// Initialize from an array of `Capability`.
    public init(rights inRights: [CapabilityRight]) {
        self.rights = {
            var rights = cap_rights_t()
            ccapsicum_rights_init(&rights)
            for right in inRights {
                ccaspsicum_cap_set(&rights, right.bridged)
            }
            return rights
        }()
    }

    public mutating func add(capability: CapabilityRight) {
        ccaspsicum_cap_set(&self.rights, capability.bridged)
    }

    public mutating func add(capabilites: [CapabilityRight]) {
        for cap in capabilites {
            ccaspsicum_cap_set(&self.rights, cap.bridged)
        }
    }

    public mutating func clear(capability: CapabilityRight) {            
        ccapsicum_rights_clear(&self.rights, capability.bridged)
    }

    public mutating func clear(capabilites: [CapabilityRight]) {
        for cap in capabilites {               
            ccapsicum_rights_clear(&self.rights, cap.bridged)
        }
    }

    public mutating func contains(capability: CapabilityRight) -> Bool {
        return ccapsicum_right_is_set(&self.rights, capability.bridged)
    }

    public mutating func contains(right other: CapabilityRightSet) -> Bool {
        var contains = false
        withUnsafePointer(to: other.rights) { otherRights in
            contains = ccapsicum_rights_contains(&self.rights, otherRights)
        }
        return contains
    }

    /// Returns a new merged `CapabilityRightSet`` instance.
    public mutating func merge(with other: CapabilityRightSet) {
        withUnsafePointer(to: other.rights) { srcPtr in
            _ = ccapsicum_cap_rights_merge(&self.rights, srcPtr)
        }
    }

    /// Removes rights matching `right`
    public mutating func remove(matching right: CapabilityRightSet) {
        withUnsafePointer(to: right.rights) { srcPtr in
            _ = ccapsicum_rights_remove(&self.rights, srcPtr)
        }
    }
    /// Validates the right.
    public mutating func validate() -> Bool {
        return ccapsicum_rights_valid(&rights)
    }

    public func asCapRightsT() -> cap_rights_t {
        return rights
    }

    public mutating func limit(fd: Int32) -> Bool {
        ccapsicum_cap_limit(fd, &rights) == 0
    }
}