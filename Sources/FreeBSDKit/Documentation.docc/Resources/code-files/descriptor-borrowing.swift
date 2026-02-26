import Capabilities
import Descriptors

// Functions that borrow descriptors don't take ownership
func printFileInfo(_ file: borrowing FileCapability) throws {
    // We can use the file, but don't own it
    let data = try file.read(count: 100)
    print("First 100 bytes: \(data)")
    // File stays open after this function returns
}

func example() throws {
    let file = try FileCapability.open(
        path: "/tmp/example.txt",
        flags: .readOnly
    )

    // Pass by borrowing - we retain ownership
    try printFileInfo(file)

    // File is still valid here
    let moreData = try file.read(count: 100)
    print("Next 100 bytes: \(moreData)")
}
