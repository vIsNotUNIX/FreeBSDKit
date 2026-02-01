import Foundation
import Glibc

@inline(__always)
func throwPOSIXError(_ err: Int32 = errno) throws -> Never {
    if let code = POSIXErrorCode(rawValue: err) {
        throw POSIXError(code)
    } else {
        fatalError("Unknown POSIX errno: \(err)")
    }
}
