/*
 * Kqueue Signal Handler Demo
 *
 * Demonstrates EVFILT_SIGNAL by waiting for signals from another process.
 * Run this, then from another terminal send signals using the printed commands.
 */

import Capabilities
import Descriptors
import SignalDispatchers
import FreeBSDKit
import Foundation
import Glibc

@main
struct KqueueDemo {
    static func main() throws {
        let pid = getpid()

        print("=== Kqueue Signal Handler Demo ===")
        print("PID: \(pid)")
        print()
        print("From another terminal, send signals with:")
        print("  kill -USR1 \(pid)    # Send SIGUSR1")
        print("  kill -USR2 \(pid)    # Send SIGUSR2")
        print("  kill -INT \(pid)     # Send SIGINT (exits demo)")
        print()

        // Block signals from normal delivery (required for EVFILT_SIGNAL)
        try KqueueCapability.blockSignals([.usr1, .usr2, .int])
        print("Blocked SIGUSR1, SIGUSR2, SIGINT from normal delivery")

        // Create a kqueue
        let kq = try KqueueCapability.makeKqueue()
        print("Created kqueue")

        // Register for multiple signals
        try kq.registerSignal(.usr1)
        try kq.registerSignal(.usr2)
        try kq.registerSignal(.int)
        print("Registered signals with kqueue")
        print()
        print("Waiting for signals... (SIGINT to exit)")
        print(String(repeating: "-", count: 40))

        // Event loop
        var running = true
        var signalCount = 0

        while running {
            let (count, events) = try kq.kevent(
                changes: [],
                maxEvents: 8,
                timeout: nil  // Block indefinitely
            )

            for i in 0..<count {
                let ev = events[i]
                guard ev.filter == Int16(EVFILT_SIGNAL) else { continue }

                let signo = Int32(ev.ident)
                signalCount += 1

                if let sig = BSDSignal(rawValue: signo) {
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    print("[\(timestamp)] Received \(sig) (count: \(ev.data))")

                    if sig == .int {
                        print()
                        print("SIGINT received, exiting...")
                        running = false
                    }
                }
            }
        }

        // Cleanup
        try kq.unregisterSignal(.usr1)
        try kq.unregisterSignal(.usr2)
        try kq.unregisterSignal(.int)

        print()
        print("Total signals received: \(signalCount)")
        print("Demo complete.")
    }
}
