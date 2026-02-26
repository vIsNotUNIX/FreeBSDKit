import FPC
import Capsicum
import Capabilities
import Foundation

actor SandboxedWorker {
    let endpoint: FPCEndpoint

    init(endpoint: consuming FPCEndpoint) {
        self.endpoint = endpoint
    }

    func run() async throws {
        // Enter Capsicum sandbox
        try Capsicum.enterCapabilityMode()

        await endpoint.start()

        // Request a file from the parent
        let request = Request(command: .openFile, path: "/etc/passwd", data: nil)
        let requestData = try JSONEncoder().encode(request)
        try await endpoint.send(FPCMessage(payload: requestData))

        // Receive the file descriptor
        let response = try await endpoint.receive()
        if let fd = response.descriptors.first {
            let file = FileCapability(fd.rawValue)
            let content = try file.read(count: 10000)

            // Process the data
            let processed = processContent(content)
            print("Processed \(processed.count) bytes")
        }
    }

    private func processContent(_ data: Data) -> Data {
        // Your processing logic here
        return data
    }
}
