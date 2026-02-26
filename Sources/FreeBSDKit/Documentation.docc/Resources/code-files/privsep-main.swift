import FPC
import Capabilities
import Glibc

@main
struct PrivilegeSeparatedApp {
    static func main() async throws {
        // Create socket pair for IPC
        let pair = try SocketCapability.socketPair(
            domain: .unix,
            type: [.seqpacket, .cloexec]
        )

        let pid = fork()

        if pid == 0 {
            // Child - sandboxed worker
            let endpoint = FPCEndpoint(socket: pair.second)
            let worker = SandboxedWorker(endpoint: endpoint)
            try await worker.run()
            _exit(0)
        } else {
            // Parent - privileged
            let endpoint = FPCEndpoint(socket: pair.first)
            let parent = PrivilegedParent(endpoint: endpoint)
            try await parent.run()

            var status: Int32 = 0
            waitpid(pid, &status, 0)
        }
    }
}
