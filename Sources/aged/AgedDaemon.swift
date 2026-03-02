/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import ArgumentParser
import FPC
import AgeSignal

// MARK: - AgedDaemon

/// Age signal daemon for AB-1043 compliance.
///
/// This daemon manages birthdate storage and responds to age bracket queries
/// from applications. It runs as root and listens on a Unix domain socket.
@main
struct AgedDaemon: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aged",
        abstract: "Age signal daemon for AB-1043 compliance",
        discussion: """
            The aged daemon stores user birthdates and provides age bracket
            information to applications via a Unix domain socket. It implements
            the age signal protocol for California AB-1043 compliance.

            The daemon must run as root to:
            - Store birthdates securely in /var/db/aged/
            - Authenticate peer credentials via LOCAL_PEERCRED

            Age brackets returned:
            - under13: Under 13 years old
            - 13-15: 13 to 15 years old
            - 16-17: 16 to 17 years old
            - 18+: 18 years or older
            """
    )

    @Option(name: .shortAndLong, help: "Socket path for client connections")
    var socket: String = AgeSignalProtocol.defaultSocketPath

    @Option(name: .shortAndLong, help: "Database directory for birthdate storage")
    var database: String = AgeSignalProtocol.databasePath

    @Flag(name: .shortAndLong, help: "Run in foreground (don't daemonize)")
    var foreground: Bool = false

    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose: Bool = false

    func run() async throws {
        // Check running as root
        guard geteuid() == 0 else {
            fputs("Error: aged must run as root\n", stderr)
            throw ExitCode.failure
        }

        // Initialize storage
        let storage = AgeStorage(databasePath: database)
        do {
            try await storage.ensureDirectory()
        } catch {
            fputs("Error: Failed to initialize database: \(error)\n", stderr)
            throw ExitCode.failure
        }

        // Remove stale socket if it exists
        unlink(socket)

        // Create listener
        let listener: FPCListener
        do {
            listener = try FPCListener.listen(on: socket)
        } catch {
            fputs("Error: Failed to create listener: \(error)\n", stderr)
            throw ExitCode.failure
        }

        // Set socket permissions to allow all users to connect (rw for all, no execute)
        // Authorization is handled per-request based on peer credentials
        chmod(socket, 0o666)

        log("aged daemon starting on \(socket)")
        log("Database directory: \(database)")

        // Create request handler
        let handler = RequestHandler(storage: storage, verbose: verbose)

        // Start listener
        await listener.start()

        // Handle signals
        setupSignalHandlers(listener: listener)

        log("Accepting connections...")

        // Accept connections
        do {
            let connections = try await listener.connections()
            for try await endpoint in connections {
                // Handle each connection in its own task
                Task {
                    await handleConnection(endpoint: endpoint, handler: handler)
                }
            }
        } catch {
            log("Listener error: \(error)")
        }

        // Cleanup
        await listener.stop()
        unlink(socket)
        log("aged daemon stopped")
    }

    /// Handles a single client connection.
    private func handleConnection(endpoint: FPCEndpoint, handler: RequestHandler) async {
        // Get peer credentials
        let creds: PeerCredentials
        do {
            creds = try await endpoint.getPeerCredentials()
        } catch {
            log("Failed to get peer credentials: \(error)")
            await endpoint.stop()
            return
        }

        log("Connection from PID \(creds.pid), UID \(creds.uid)")

        await endpoint.start()

        // Process messages until disconnection
        do {
            let messages = try await endpoint.incoming()
            for await message in messages {
                do {
                    try await handler.handle(
                        message: message,
                        peerCredentials: creds,
                        endpoint: endpoint
                    )
                } catch {
                    if verbose {
                        log("Error handling message: \(error)")
                    }
                }
            }
        } catch {
            if verbose {
                log("Connection error: \(error)")
            }
        }

        await endpoint.stop()
        log("Connection closed from PID \(creds.pid)")
    }

    /// Sets up signal handlers for graceful shutdown.
    private func setupSignalHandlers(listener: FPCListener) {
        // Ignore SIGPIPE (handled by socket options)
        signal(SIGPIPE, SIG_IGN)

        // TODO: Handle SIGTERM/SIGINT for graceful shutdown
        // This would require a more sophisticated approach with signalfd or kqueue
    }

    private func log(_ message: String) {
        if verbose || foreground {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("[\(timestamp)] \(message)")
        }
    }
}
