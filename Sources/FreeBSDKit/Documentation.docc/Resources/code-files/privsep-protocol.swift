import Foundation

// Define commands for the privilege-separated protocol
enum Command: String, Codable {
    case openFile = "OPEN_FILE"
    case processData = "PROCESS"
    case shutdown = "SHUTDOWN"
}

struct Request: Codable {
    let command: Command
    let path: String?
    let data: Data?
}

struct Response: Codable {
    let success: Bool
    let error: String?
    let data: Data?
}
