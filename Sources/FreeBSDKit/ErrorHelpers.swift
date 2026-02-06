import Foundation
import Glibc

public enum BSDError: Error, Sendable, CustomStringConvertible {
    public case posix(POSIXError)
    public case errno(Int32)

    public var description: String {
        switch self {
        case .posix(let err):
            return String(describing: err)
        case .errno(let value):
            return "errno \(value)"
        }
    }

    @inline(__always)
    public static func throwErrno(_ err: Int32 = errno) throws -> Never {
        throw BSDError.fromErrno(err)
    }

    @inline(__always)
    public static func fromErrno(_ err: Int32 = errno) -> BSDError {
        if let code = POSIXErrorCode(rawValue: err) {
            return .posix(POSIXError(code))
        } else {
            return .errno(err)
        }
    }
}