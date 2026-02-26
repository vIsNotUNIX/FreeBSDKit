import FreeBSDKit
import Glibc

// Create BSDError from an errno value
let error = BSDError(errno: ENOENT)
print(error.localizedDescription) // "No such file or directory"

// Check if an error matches a specific errno
if error.errno == ENOENT {
    print("File not found")
}
