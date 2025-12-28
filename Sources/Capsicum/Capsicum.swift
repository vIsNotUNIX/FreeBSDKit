import CCapsicum

public enum Capsicum {
    public static func enterCapabilityMode() -> Int32 {
        return cap_enter()
    }
}