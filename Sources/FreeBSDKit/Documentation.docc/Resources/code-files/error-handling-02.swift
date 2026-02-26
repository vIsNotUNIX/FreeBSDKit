import FreeBSDKit

do {
    let data = try ExtendedAttribute.get(
        name: "user.example",
        path: "/some/path"
    )
    print("Value: \(data)")
} catch let error as BSDError {
    // Handle specific BSD errors
    switch error {
    case .noSuchFileOrDirectory:
        print("File does not exist")
    case .permissionDenied:
        print("Permission denied - try running as root")
    case .notSupported:
        print("Extended attributes not supported on this filesystem")
    default:
        print("BSD error: \(error.localizedDescription)")
    }
} catch {
    print("Unexpected error: \(error)")
}
