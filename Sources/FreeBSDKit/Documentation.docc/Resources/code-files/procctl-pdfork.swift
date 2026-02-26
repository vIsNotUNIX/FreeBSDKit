import Procctl
import Capabilities
import Glibc

// pdfork creates a process descriptor instead of returning a PID
// This is Capsicum-friendly - you can manage the child via the descriptor

var pd: Int32 = -1
let pid = pdfork(&pd, 0)

if pid == 0 {
    // Child process
    print("Child running")
    _exit(0)
} else {
    // Parent - we have a process descriptor
    print("Child process descriptor: \(pd)")

    // Convert to ProcessCapability for type safety
    let child = ProcessCapability(pd)

    // Wait for child using the descriptor
    let status = try child.wait()
    print("Child exited with status: \(status)")

    // Works in Capsicum capability mode!
}
