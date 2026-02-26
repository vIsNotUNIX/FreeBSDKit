import FreeBSDKit
import Glibc

do {
    // Some operation...
    throw BSDError.permissionDenied
} catch let error as BSDError {
    // Access the raw errno value for C interop
    let errnoValue = error.errno

    // Use with C functions that expect errno
    print("errno = \(errnoValue)")

    // Get the system error message
    if let message = String(validatingUTF8: strerror(errnoValue)) {
        print("System message: \(message)")
    }
}
