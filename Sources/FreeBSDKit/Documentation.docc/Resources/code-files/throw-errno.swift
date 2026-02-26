import FreeBSDKit
import Glibc

func mySystemCall() throws {
    // Call a system function
    let result = open("/nonexistent", O_RDONLY)

    if result < 0 {
        // Convert errno to BSDError and throw
        try BSDError.throwErrno(errno)
    }

    // Success - use result
    close(result)
}

// Usage
do {
    try mySystemCall()
} catch {
    print("Failed: \(error)")
}
