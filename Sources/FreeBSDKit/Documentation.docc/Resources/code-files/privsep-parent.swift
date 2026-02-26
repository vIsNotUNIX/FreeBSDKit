import FPC
import Capabilities
import Foundation

actor PrivilegedParent {
    let endpoint: FPCEndpoint

    init(endpoint: consuming FPCEndpoint) {
        self.endpoint = endpoint
    }

    func run() async throws {
        await endpoint.start()

        for try await message in try endpoint.messages() {
            let request = try JSONDecoder().decode(Request.self, from: message.payload)
            try await handleRequest(request)
        }
    }

    private func handleRequest(_ request: Request) async throws {
        switch request.command {
        case .openFile:
            guard let path = request.path else { return }
            let file = try FileCapability.open(path: path, flags: .readOnly)

            // Send the file descriptor to the worker
            try await endpoint.send(FPCMessage(
                payload: Data(),
                descriptors: [file.toOpaqueRef()]
            ))

        case .processData:
            // Handle processed data from worker
            break

        case .shutdown:
            await endpoint.stop()
        }
    }
}
