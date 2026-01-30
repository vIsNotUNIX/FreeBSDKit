// MARK: - Jail Flags

import CJails

public struct JailSetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let create  = JailSetFlags(rawValue: JAIL_CREATE)
    public static let update  = JailSetFlags(rawValue: JAIL_UPDATE)
    public static let attach  = JailSetFlags(rawValue: JAIL_ATTACH)

    public static let useDesc = JailSetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc  = JailSetFlags(rawValue: JAIL_AT_DESC)
    public static let getDesc = JailSetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc = JailSetFlags(rawValue: JAIL_OWN_DESC)
}

public struct JailGetFlags: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let dying   = JailGetFlags(rawValue: JAIL_DYING)
    public static let useDesc = JailGetFlags(rawValue: JAIL_USE_DESC)
    public static let atDesc  = JailGetFlags(rawValue: JAIL_AT_DESC)
    public static let getDesc = JailGetFlags(rawValue: JAIL_GET_DESC)
    public static let ownDesc = JailGetFlags(rawValue: JAIL_OWN_DESC)
}