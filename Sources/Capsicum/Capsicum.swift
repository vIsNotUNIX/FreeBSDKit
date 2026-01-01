import CCapsicum

enum CapsicumError: Error {
    case sandboxUnspported
}

/// A Swift interface to capability mode.
public enum Capsicum {
    /// Enters capability mode.
    public static func enter() throws {
        guard cap_enter() == 0 else {
            throw CapsicumError.sandboxUnspported
        }
    }
    /// Returns `true` if the process is in capability mode.
    public static func status() throws -> Bool {
        var mode: UInt32 = 0
        guard cap_getmode(&mode) == 0 else {
            throw CapsicumError.sandboxUnspported
        }
        return mode == 1
    }
}

