import FreeBSDKit

do {
    // Try to read an extended attribute
    let data = try ExtendedAttribute.get(
        name: "user.example",
        path: "/nonexistent/file"
    )
    print("Value: \(data)")
} catch {
    // Handle any error
    print("Error: \(error)")
}
