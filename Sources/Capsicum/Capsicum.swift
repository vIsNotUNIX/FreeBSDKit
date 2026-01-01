import CCapsicum

enum CapsicumError: Error {
    /// Thrown when the system is not compiled with Capsicum support.
    case capsicumUnsupported
}

/// An interface for FreeBSD Capsicum.
/// man: capsicum
public enum Capsicum {
    /// Enters capability mode.
    /// `man cap_enter`
    public static func enter() throws {
        guard cap_enter() == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
    }
    /// Returns `true` if the process is in Capability mode.
    /// `man cap_getmode`
    public static func status() throws -> Bool {
        var mode: UInt32 = 0
        guard cap_getmode(&mode) == 0 else {
            throw CapsicumError.capsicumUnsupported
        }
        return mode == 1
    }
}

