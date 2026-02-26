import FreeBSDKit
import Foundation

// Read extended attributes from a file
let path = "/tmp/testfile"

// Create a test file
FileManager.default.createFile(atPath: path, contents: nil)

// Set an extended attribute
try ExtendedAttribute.set(
    name: "user.example",
    value: Data("Hello, FreeBSD!".utf8),
    path: path
)

// Read it back
if let data = try ExtendedAttribute.get(name: "user.example", path: path) {
    let value = String(data: data, encoding: .utf8)!
    print("Extended attribute value: \(value)")
}

// List all extended attributes
let attrs = try ExtendedAttribute.list(path: path)
print("Extended attributes: \(attrs)")
