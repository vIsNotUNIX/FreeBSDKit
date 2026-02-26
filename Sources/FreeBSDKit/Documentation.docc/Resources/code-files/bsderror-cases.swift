import FreeBSDKit

// Common BSDError cases
let errors: [BSDError] = [
    .permissionDenied,    // EACCES - Permission denied
    .noSuchFileOrDirectory, // ENOENT - No such file or directory
    .fileExists,          // EEXIST - File exists
    .isADirectory,        // EISDIR - Is a directory
    .notADirectory,       // ENOTDIR - Not a directory
    .invalidArgument,     // EINVAL - Invalid argument
    .operationNotPermitted, // EPERM - Operation not permitted
    .resourceBusy,        // EBUSY - Device or resource busy
]

// Each error has a description
for error in errors {
    print("\(error.errno): \(error.localizedDescription)")
}
