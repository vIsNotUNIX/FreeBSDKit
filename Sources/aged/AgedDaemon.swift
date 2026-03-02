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
import Capsicum
import Casper
import Capabilities
import Descriptors
import Audit
import SignalDispatchers
import FreeBSDKit

// MARK: - SignalLogger

/// Wrapper to allow capturing CasperSyslog in signal handler closures.
///
/// Since `CasperSyslog` is `~Copyable`, it can't be captured directly in
/// the `@Sendable` closures used by `GCDSignalHandler`. This class wraps
/// the syslog service to enable capture.
private final class SignalLogger: @unchecked Sendable {
    private var syslog: CasperSyslog

    init(syslog: consuming CasperSyslog) {
        self.syslog = syslog
    }

    func info(_ message: String) {
        syslog.info(message)
    }

    func notice(_ message: String) {
        syslog.notice(message)
    }
}

// MARK: - AgedDaemon

/// Age signal daemon for AB-1043 compliance.
///
/// This daemon manages birthdate storage and responds to age bracket queries
/// from applications. It runs as root and listens on a Unix domain socket.
///
/// ## Security Model
///
/// The daemon enters Capsicum capability mode after initialization, restricting
/// itself to only the resources it needs:
/// - The listening socket (for accepting connections)
/// - The database directory (`/var/db/aged/`)
/// - Casper services for syslog and password lookups
///
/// All filesystem access by path is disabled after initialization.
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

            After initialization, the daemon enters Capsicum capability mode
            for defense in depth.

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

    @Flag(name: .long, help: "Disable Capsicum sandboxing (for debugging)")
    var noSandbox: Bool = false

    func run() async throws {
        // Check running as root
        guard geteuid() == 0 else {
            fputs("Error: aged must run as root\n", stderr)
            throw ExitCode.failure
        }

        // =====================================================================
        // Phase 1: Pre-sandbox initialization
        // All resources must be opened before entering capability mode
        // =====================================================================

        // Initialize Casper channel (must be done before cap_enter)
        let casper = try createCasperChannel()

        // Create syslog services (one for request handler, one for signal handler)
        let syslogService = try CasperSyslog(casper: try casper.clone())
        let signalLogService = try CasperSyslog(casper: try casper.clone())
        let pwdService = try createPwdService(casper: casper)

        // Open syslog before sandbox
        syslogService.openlog(ident: "aged", options: [.pid, .ndelay], facility: .daemon)
        signalLogService.openlog(ident: "aged", options: [.pid, .ndelay], facility: .daemon)

        // Log startup (before services are transferred to handler)
        syslogService.info("aged daemon initializing")

        // Ensure database directory exists (before sandbox)
        try ensureDatabaseDirectory(database: database, logger: syslogService)

        // Open database directory capability (before sandbox)
        let dbDir = try openDatabaseDirectory(path: database, logger: syslogService)

        // Initialize storage with directory capability
        let storage = AgeStorage(directory: dbDir)

        // Remove stale socket if it exists
        unlink(socket)

        // Create listener (before sandbox)
        let listener = try createListener(socketPath: socket, logger: syslogService)

        // Set socket permissions
        chmod(socket, 0o666)

        syslogService.info("aged daemon starting on \(socket)")
        syslogService.info("Database directory: \(database)")

        if verbose || foreground {
            print("aged daemon starting on \(socket)")
            print("Database directory: \(database)")
        }

        // =====================================================================
        // Phase 2: Enter Capsicum capability mode
        // =====================================================================

        if !noSandbox {
            do {
                try Capsicum.enter()
                syslogService.info("Entered Capsicum capability mode")
                if verbose || foreground {
                    print("Entered Capsicum capability mode")
                }
            } catch {
                syslogService.warning("Failed to enter capability mode: \(error)")
                if verbose || foreground {
                    print("Warning: Failed to enter capability mode: \(error)")
                }
                // Continue without sandbox
            }
        } else {
            syslogService.warning("Sandbox disabled (--no-sandbox flag)")
            if verbose || foreground {
                print("Warning: Sandbox disabled (--no-sandbox flag)")
            }
        }

        // =====================================================================
        // Phase 3: Main loop (sandboxed)
        // =====================================================================

        // Create request handler with Casper services (transfers ownership)
        let handler = RequestHandler(
            storage: storage,
            pwdService: pwdService,
            logService: syslogService,
            verbose: verbose
        )

        // Start listener
        await listener.start()

        // Set up signal handlers for graceful shutdown
        let signalHandler = try setupSignalHandlers(
            listener: listener,
            logger: signalLogService,
            verbose: verbose || foreground
        )

        if verbose || foreground {
            print("Accepting connections...")
        }

        // Accept connections
        do {
            let connections = try await listener.connections()
            for try await endpoint in connections {
                // Handle each connection in its own task
                Task {
                    await handleConnection(
                        endpoint: endpoint,
                        handler: handler,
                        verbose: verbose
                    )
                }
            }
        } catch {
            if verbose || foreground {
                print("Listener error: \(error)")
            }
        }

        // Cleanup
        signalHandler.cancel()
        await listener.stop()
        // Note: Can't unlink(socket) in capability mode - socket will be cleaned up on next start
        if verbose || foreground {
            print("aged daemon stopped")
        }
    }

    // MARK: - Initialization Helpers

    /// Creates the main Casper channel.
    private func createCasperChannel() throws -> CasperChannel {
        do {
            return try CasperChannel.create()
        } catch {
            fputs("Error: Failed to create Casper channel: \(error)\n", stderr)
            fputs("Is casper(8) running?\n", stderr)
            throw ExitCode.failure
        }
    }

    /// Creates and configures the password service.
    private func createPwdService(casper: borrowing CasperChannel) throws -> CasperPwd {
        do {
            let pwdService = try CasperPwd(casper: try casper.clone())
            // Limit pwd service to only what we need
            try pwdService.limitCommands([CasperPwd.Command.getpwuid])
            try pwdService.limitFields([CasperPwd.Field.uid, CasperPwd.Field.gid, CasperPwd.Field.name])
            return pwdService
        } catch {
            fputs("Error: Failed to create pwd service: \(error)\n", stderr)
            throw ExitCode.failure
        }
    }

    /// Ensures the database directory exists with proper permissions.
    private func ensureDatabaseDirectory(database: String, logger: borrowing CasperSyslog) throws {
        var st = stat()
        if stat(database, &st) != 0 {
            if mkdir(database, 0o700) != 0 {
                logger.error("Failed to create \(database): \(String(cString: strerror(errno)))")
                throw ExitCode.failure
            }
        } else if (st.st_mode & S_IFMT) != S_IFDIR {
            logger.error("\(database) exists but is not a directory")
            throw ExitCode.failure
        }
        // Ensure permissions
        if chmod(database, 0o700) != 0 {
            logger.error("Failed to set permissions on \(database)")
            throw ExitCode.failure
        }
    }

    /// Opens the database directory as a capability.
    private func openDatabaseDirectory(path: String, logger: borrowing CasperSyslog) throws -> DirectoryCapability {
        do {
            return try DirectoryCapability.open(path: path, flags: [.closeOnExec])
        } catch {
            logger.error("Failed to open database directory: \(error)")
            throw ExitCode.failure
        }
    }

    /// Creates the FPC listener.
    private func createListener(socketPath: String, logger: borrowing CasperSyslog) throws -> FPCListener {
        do {
            return try FPCListener.listen(on: socketPath)
        } catch {
            logger.error("Failed to create listener: \(error)")
            throw ExitCode.failure
        }
    }

    // MARK: - Connection Handling

    /// Handles a single client connection.
    private func handleConnection(
        endpoint: FPCEndpoint,
        handler: RequestHandler,
        verbose: Bool
    ) async {
        // Get peer credentials
        let creds: PeerCredentials
        do {
            creds = try await endpoint.getPeerCredentials()
        } catch {
            if verbose {
                print("Failed to get peer credentials: \(error)")
            }
            await endpoint.stop()
            return
        }

        if verbose {
            print("Connection from PID \(creds.pid), UID \(creds.uid)")
        }

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
                        print("Error handling message: \(error)")
                    }
                }
            }
        } catch {
            if verbose {
                print("Connection error: \(error)")
            }
        }

        await endpoint.stop()
        if verbose {
            print("Connection closed from PID \(creds.pid)")
        }
    }

    /// Sets up signal handlers for graceful shutdown.
    ///
    /// Uses `GCDSignalHandler` to handle SIGTERM, SIGINT, and SIGHUP.
    /// When a termination signal is received, the listener is stopped
    /// which causes the connection loop to exit gracefully.
    ///
    /// - Parameters:
    ///   - listener: The FPC listener to stop on shutdown
    ///   - logger: Syslog service for logging signal events (consumed)
    ///   - verbose: Whether to print to stdout
    /// - Returns: The signal handler (caller should call `cancel()` on cleanup)
    private func setupSignalHandlers(
        listener: FPCListener,
        logger: consuming CasperSyslog,
        verbose: Bool
    ) throws -> GCDSignalHandler {
        let handler = try GCDSignalHandler(signals: [.term, .int, .hup])

        // Wrap logger for capture in closures
        let log = SignalLogger(syslog: logger)

        handler.on(.term) {
            log.notice("Received SIGTERM, initiating shutdown")
            if verbose {
                print("Received SIGTERM, shutting down...")
            }
            Task {
                await listener.stop()
            }
        }

        handler.on(.int) {
            log.notice("Received SIGINT, initiating shutdown")
            if verbose {
                print("Received SIGINT, shutting down...")
            }
            Task {
                await listener.stop()
            }
        }

        handler.on(.hup) {
            log.info("Received SIGHUP (ignored, no config to reload)")
            if verbose {
                print("Received SIGHUP (ignored)")
            }
        }

        return handler
    }
}
