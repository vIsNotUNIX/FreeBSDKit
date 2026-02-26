import Capabilities
import Descriptors
import Capsicum
import Foundation
import Glibc

/// Privilege-separated application pattern:
/// - Parent: Privileged, opens files on request
/// - Child: Sandboxed, processes files

func main() throws {
    // Create socket pair for IPC
    let pair = try SocketCapability.socketPair(
        domain: .unix,
        type: [.seqpacket, .cloexec]
    )

    let pid = fork()

    if pid == 0 {
        // === CHILD (SANDBOXED WORKER) ===
        try runWorker(socket: pair.second)
    } else {
        // === PARENT (PRIVILEGED OPENER) ===
        try runOpener(socket: pair.first)

        // Wait for child
        var status: Int32 = 0
        waitpid(pid, &status, 0)
    }
}

func runOpener(socket: consuming SocketCapability) throws {
    print("[Opener] Running as privileged process")

    while true {
        // Wait for file request from worker
        let (payload, _) = try socket.recvDescriptors(bufferSize: 1024)
        let request = String(data: payload, encoding: .utf8) ?? ""

        if request == "DONE" {
            break
        }

        // Open the requested file
        guard request.hasPrefix("OPEN:") else { continue }
        let path = String(request.dropFirst(5)).trimmingCharacters(in: .newlines)

        print("[Opener] Opening: \(path)")

        do {
            let file = try FileCapability.open(path: path, flags: .readOnly)
            try socket.sendDescriptors([file.toOpaqueRef()], payload: Data("OK".utf8))
        } catch {
            try socket.sendDescriptors([], payload: Data("ERROR:\(error)".utf8))
        }
    }
}

func runWorker(socket: consuming SocketCapability) throws {
    print("[Worker] Entering Capsicum sandbox")

    // Enter capability mode - no more filesystem access!
    try Capsicum.enterCapabilityMode()

    // Request files through the opener
    let filesToProcess = ["/etc/passwd", "/etc/group"]

    for path in filesToProcess {
        // Request file from opener
        try socket.write(Data("OPEN:\(path)\n".utf8))

        // Receive the file descriptor
        let (response, fds) = try socket.recvDescriptors(
            maxDescriptors: 1,
            bufferSize: 256
        )

        let status = String(data: response, encoding: .utf8) ?? ""
        if status == "OK", let fd = fds.first {
            let file = FileCapability(fd.rawValue)
            let content = try file.read(count: 1024)
            print("[Worker] Read \(content.count) bytes from \(path)")
        } else {
            print("[Worker] Failed to open \(path): \(status)")
        }
    }

    // Signal done
    try socket.write(Data("DONE".utf8))
}
