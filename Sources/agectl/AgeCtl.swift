/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import ArgumentParser
import AgeSignal
import FPC
import Capsicum
import Casper
import Audit

// MARK: - Audit Event

/// BSM audit event number for agectl operations.
/// Uses AUE_audit_user (32767) for application-generated audit records.
private let AUE_AGECTL: Audit.EventNumber = 32767

// MARK: - AgeCtl

/// Administrative tool for managing age signals.
///
/// This CLI tool communicates with the aged daemon to set, query, and remove
/// user birthdates. Most operations require root privileges.
///
/// ## Security Model
///
/// After parsing arguments and connecting to the daemon, agectl enters
/// Capsicum capability mode. This prevents any further filesystem access
/// or network connections - only the pre-opened socket to aged can be used.
///
/// Casper services are used for:
/// - Syslog: Logging operations to system log (works in capability mode)
/// - Pwd: Username lookups (done before entering capability mode)
///
/// Security-relevant operations (set/remove) are logged to syslog and
/// submitted as BSM audit events.
@main
struct AgeCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agectl",
        abstract: "Manage age signals for AB-1043 compliance",
        discussion: """
            agectl communicates with the aged daemon to manage user birthdates
            and query age brackets.

            Examples:
              agectl query                     # Query your own age bracket
              agectl query -u 1001             # Query another user (privileged)
              agectl set -u 1001 -b 2010-06-15 # Set birthdate (requires root)
              agectl remove -u 1001            # Remove birthdate (requires root)
            """,
        subcommands: [Query.self, Set.self, Remove.self]
    )
}

// MARK: - Security Context

/// Security context for sandboxed operations.
///
/// This struct holds references to Casper services that work within
/// Capsicum capability mode. It's created before entering the sandbox
/// and passed to operations that need logging/audit capabilities.
struct SecurityContext: ~Copyable {
    let syslog: CasperSyslog

    init(syslog: consuming CasperSyslog) {
        self.syslog = syslog
    }

    /// Logs a message to syslog (auth facility for security events).
    func logAuth(_ message: String) {
        syslog.log(.notice, facility: .auth, message)
    }

    /// Submits a BSM audit event.
    func audit(message: String, success: Bool, error: Int32 = 0) {
        do {
            try Audit.submit(
                event: AUE_AGECTL,
                message: message,
                success: success,
                error: error
            )
        } catch {
            // Audit failure is not fatal
        }
    }
}

/// Creates the security context (Casper services) before entering sandbox.
///
/// - Returns: A SecurityContext, or nil if Casper services unavailable.
private func createSecurityContext() -> SecurityContext? {
    do {
        let casper = try CasperChannel.create()
        let syslogService = try CasperSyslog(casper: try casper.clone())
        syslogService.openlog(ident: "agectl", options: [.pid, .ndelay], facility: .auth)
        return SecurityContext(syslog: syslogService)
    } catch {
        // Casper not available - continue without logging
        return nil
    }
}

/// Enters Capsicum capability mode.
private func enterSandbox() {
    do {
        try Capsicum.enter()
    } catch {
        // Sandbox failure is not fatal for the client
    }
}

// MARK: - User Resolution Helpers

/// Resolves a username to a UID.
///
/// - Parameter username: The username to resolve
/// - Returns: The UID for the username
/// - Throws: `ValidationError` if the user doesn't exist
private func resolveUsername(_ username: String) throws -> UInt32 {
    guard let pwd = getpwnam(username) else {
        throw ValidationError("User not found: \(username)")
    }
    return pwd.pointee.pw_uid
}

/// Gets the username for a UID.
///
/// - Parameter uid: The UID to look up
/// - Returns: The username, or nil if not found
private func usernameForUID(_ uid: UInt32) -> String? {
    guard let pwd = getpwuid(uid) else {
        return nil
    }
    return String(cString: pwd.pointee.pw_name)
}

// MARK: - Query Command

extension AgeCtl {
    struct Query: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query age bracket for a user"
        )

        @Option(name: .shortAndLong, help: "User ID to query (default: current user)")
        var user: UInt32?

        @Option(name: [.long, .customShort("U")], help: "Username to query")
        var username: String?

        @Option(name: .shortAndLong, help: "Socket path")
        var socket: String = AgeSignalProtocol.defaultSocketPath

        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json: Bool = false

        func validate() throws {
            if user != nil && username != nil {
                throw ValidationError("Cannot specify both --user and --username")
            }
        }

        func run() async throws {
            // Phase 1: Pre-sandbox - initialize security context
            // (Query operations don't need logging, but we create it
            // anyway for consistency and potential future use)
            _ = createSecurityContext()

            // Phase 2: Pre-sandbox - resolve usernames and gather info
            let myUID = getuid()
            let myUsername = usernameForUID(myUID)

            // Resolve target username to UID if provided
            let targetUID: UInt32? = try username.map { try resolveUsername($0) } ?? user

            // Get target user's name for output (before sandbox)
            let targetUsername = targetUID.flatMap { usernameForUID($0) }

            // Phase 3: Connect to daemon
            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                fputs("Is the aged daemon running?\n", stderr)
                throw ExitCode.failure
            }

            // Phase 4: Enter sandbox - no more filesystem access
            enterSandbox()

            defer {
                Task {
                    await client.disconnect()
                }
            }

            // Phase 5: Perform operation (sandboxed)
            let result: AgeSignalResult
            if let uid = targetUID {
                result = try await client.queryBracket(for: uid)
            } else {
                result = try await client.queryOwnBracket()
            }

            // Phase 6: Output results
            if json {
                printJSON(result: result, uid: targetUID ?? myUID)
            } else {
                printHuman(
                    result: result,
                    targetUID: targetUID,
                    targetUsername: targetUsername,
                    myUID: myUID,
                    myUsername: myUsername
                )
            }

            // Note: Query operations are not logged/audited as they are
            // read-only and already authorized by the daemon
        }

        private func printJSON(result: AgeSignalResult, uid: UInt32) {
            switch result {
            case .bracket(let bracket):
                print("""
                {"status":"ok","uid":\(uid),"bracket":"\(bracket.description)","bracket_code":\(bracket.rawValue)}
                """)
            case .notSet:
                print("""
                {"status":"not_set","uid":\(uid)}
                """)
            case .permissionDenied:
                print("""
                {"status":"permission_denied","uid":\(uid)}
                """)
            case .unknownUser:
                print("""
                {"status":"unknown_user","uid":\(uid)}
                """)
            case .error(let error):
                print("""
                {"status":"error","uid":\(uid),"message":"\(error.localizedDescription)"}
                """)
            }
        }

        private func printHuman(
            result: AgeSignalResult,
            targetUID: UInt32?,
            targetUsername: String?,
            myUID: uid_t,
            myUsername: String?
        ) {
            let userDesc: String
            if let uid = targetUID {
                if let name = targetUsername {
                    userDesc = "\(name) (UID \(uid))"
                } else {
                    userDesc = "UID \(uid)"
                }
            } else {
                if let name = myUsername {
                    userDesc = "\(name) (you)"
                } else {
                    userDesc = "UID \(myUID) (you)"
                }
            }

            switch result {
            case .bracket(let bracket):
                print("Age bracket for \(userDesc): \(bracket.humanReadable)")
            case .notSet:
                print("Age bracket for \(userDesc): Not configured")
            case .permissionDenied:
                fputs("Error: Permission denied to query \(userDesc)\n", stderr)
            case .unknownUser:
                fputs("Error: User not found\n", stderr)
            case .error(let error):
                fputs("Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}

// MARK: - Set Command

extension AgeCtl {
    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set birthdate for a user (requires root)"
        )

        @Option(name: .shortAndLong, help: "User ID to set birthdate for")
        var user: UInt32?

        @Option(name: [.long, .customShort("U")], help: "Username to set birthdate for")
        var username: String?

        @Option(name: .shortAndLong, help: "Birthdate in YYYY-MM-DD format")
        var birthdate: String

        @Option(name: .shortAndLong, help: "Socket path")
        var socket: String = AgeSignalProtocol.defaultSocketPath

        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json: Bool = false

        func validate() throws {
            if user == nil && username == nil {
                throw ValidationError("Must specify either --user or --username")
            }
            if user != nil && username != nil {
                throw ValidationError("Cannot specify both --user and --username")
            }
        }

        func run() async throws {
            // Check root
            guard geteuid() == 0 else {
                fputs("Error: Setting birthdate requires root privileges\n", stderr)
                throw ExitCode.failure
            }

            // Phase 1: Pre-sandbox - initialize security context
            let securityContext = createSecurityContext()

            // Phase 2: Pre-sandbox - resolve usernames and parse input
            let targetUID: UInt32 = try username.map { try resolveUsername($0) } ?? user!

            // Get username for output and logging (before sandbox)
            let targetUsername = usernameForUID(targetUID)

            // Parse birthdate
            let bd: Birthdate
            do {
                bd = try Birthdate(parsing: birthdate)
            } catch {
                fputs("Error: Invalid birthdate format. Use YYYY-MM-DD\n", stderr)
                throw ExitCode.failure
            }

            // Phase 3: Connect to daemon
            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                throw ExitCode.failure
            }

            // Phase 4: Enter sandbox
            enterSandbox()

            defer {
                Task {
                    await client.disconnect()
                }
            }

            // Phase 5: Perform operation (sandboxed)
            let userDesc = targetUsername ?? "UID \(targetUID)"

            do {
                try await client.setBirthdate(bd, for: targetUID)
            } catch {
                // Log failure
                let message = "agectl: SET_BIRTHDATE failed for \(userDesc): \(error)"
                securityContext?.logAuth(message)
                securityContext?.audit(message: message, success: false, error: EPERM)

                fputs("Error: Failed to set birthdate: \(error)\n", stderr)
                throw ExitCode.failure
            }

            // Phase 6: Log success and output results
            let bracket = bd.currentBracket()
            let message = "agectl: SET_BIRTHDATE for \(userDesc) (bracket=\(bracket))"
            securityContext?.logAuth(message)
            securityContext?.audit(message: message, success: true)

            if json {
                print("""
                {"status":"ok","uid":\(targetUID),"bracket":"\(bracket.description)","bracket_code":\(bracket.rawValue)}
                """)
            } else {
                print("Birthdate set for \(userDesc)")
                print("Current age bracket: \(bracket.humanReadable)")
            }
        }
    }
}

// MARK: - Remove Command

extension AgeCtl {
    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove birthdate for a user (requires root)"
        )

        @Option(name: .shortAndLong, help: "User ID to remove birthdate for")
        var user: UInt32?

        @Option(name: [.long, .customShort("U")], help: "Username to remove birthdate for")
        var username: String?

        @Option(name: .shortAndLong, help: "Socket path")
        var socket: String = AgeSignalProtocol.defaultSocketPath

        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json: Bool = false

        func validate() throws {
            if user == nil && username == nil {
                throw ValidationError("Must specify either --user or --username")
            }
            if user != nil && username != nil {
                throw ValidationError("Cannot specify both --user and --username")
            }
        }

        func run() async throws {
            // Check root
            guard geteuid() == 0 else {
                fputs("Error: Removing birthdate requires root privileges\n", stderr)
                throw ExitCode.failure
            }

            // Phase 1: Pre-sandbox - initialize security context
            let securityContext = createSecurityContext()

            // Phase 2: Pre-sandbox - resolve usernames
            let targetUID: UInt32 = try username.map { try resolveUsername($0) } ?? user!

            // Get username for output and logging (before sandbox)
            let targetUsername = usernameForUID(targetUID)

            // Phase 3: Connect to daemon
            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                throw ExitCode.failure
            }

            // Phase 4: Enter sandbox
            enterSandbox()

            defer {
                Task {
                    await client.disconnect()
                }
            }

            // Phase 5: Perform operation (sandboxed)
            let userDesc = targetUsername ?? "UID \(targetUID)"

            do {
                try await client.removeBirthdate(for: targetUID)
            } catch {
                // Log failure
                let message = "agectl: REMOVE_BIRTHDATE failed for \(userDesc): \(error)"
                securityContext?.logAuth(message)
                securityContext?.audit(message: message, success: false, error: EPERM)

                fputs("Error: Failed to remove birthdate: \(error)\n", stderr)
                throw ExitCode.failure
            }

            // Phase 6: Log success and output results
            let message = "agectl: REMOVE_BIRTHDATE for \(userDesc)"
            securityContext?.logAuth(message)
            securityContext?.audit(message: message, success: true)

            if json {
                print("""
                {"status":"ok","uid":\(targetUID)}
                """)
            } else {
                print("Birthdate removed for \(userDesc)")
            }
        }
    }
}
