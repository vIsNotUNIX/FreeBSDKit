import Capabilities
import Descriptors

// Open a directory
let dir = try DirectoryCapability.open(
    path: "/var/log",
    flags: [.readOnly, .directory]
)

// List directory contents
let entries = try dir.readDirectory()

for entry in entries {
    let typeStr: String
    switch entry.type {
    case .regular:   typeStr = "file"
    case .directory: typeStr = "dir"
    case .symlink:   typeStr = "link"
    default:         typeStr = "other"
    }
    print("\(typeStr)\t\(entry.name)")
}
