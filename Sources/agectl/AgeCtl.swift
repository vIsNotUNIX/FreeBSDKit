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

// MARK: - AgeCtl

/// Administrative tool for managing age signals.
///
/// This CLI tool communicates with the aged daemon to set, query, and remove
/// user birthdates. Most operations require root privileges.
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
            let targetUID: UInt32?

            // Resolve username to UID if provided
            if let username = username {
                guard let pwd = getpwnam(username) else {
                    throw ValidationError("User not found: \(username)")
                }
                targetUID = pwd.pointee.pw_uid
            } else {
                targetUID = user
            }

            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                fputs("Is the aged daemon running?\n", stderr)
                throw ExitCode.failure
            }

            defer {
                Task {
                    await client.disconnect()
                }
            }

            let result: AgeSignalResult
            if let uid = targetUID {
                result = try await client.queryBracket(for: uid)
            } else {
                result = try await client.queryOwnBracket()
            }

            if json {
                printJSON(result: result, uid: targetUID ?? UInt32(getuid()))
            } else {
                printHuman(result: result, uid: targetUID)
            }
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

        private func printHuman(result: AgeSignalResult, uid: UInt32?) {
            let userDesc: String
            if let uid = uid {
                if let pwd = getpwuid(uid) {
                    userDesc = "\(String(cString: pwd.pointee.pw_name)) (UID \(uid))"
                } else {
                    userDesc = "UID \(uid)"
                }
            } else {
                let myUID = getuid()
                if let pwd = getpwuid(myUID) {
                    userDesc = "\(String(cString: pwd.pointee.pw_name)) (you)"
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

            // Resolve username to UID if provided
            let targetUID: UInt32
            if let username = username {
                guard let pwd = getpwnam(username) else {
                    throw ValidationError("User not found: \(username)")
                }
                targetUID = pwd.pointee.pw_uid
            } else {
                targetUID = user!
            }

            // Parse birthdate
            let bd: Birthdate
            do {
                bd = try Birthdate(parsing: birthdate)
            } catch {
                fputs("Error: Invalid birthdate format. Use YYYY-MM-DD\n", stderr)
                throw ExitCode.failure
            }

            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                throw ExitCode.failure
            }

            defer {
                Task {
                    await client.disconnect()
                }
            }

            do {
                try await client.setBirthdate(bd, for: targetUID)
            } catch {
                fputs("Error: Failed to set birthdate: \(error)\n", stderr)
                throw ExitCode.failure
            }

            let bracket = bd.currentBracket()

            if json {
                print("""
                {"status":"ok","uid":\(targetUID),"bracket":"\(bracket.description)","bracket_code":\(bracket.rawValue)}
                """)
            } else {
                let userDesc: String
                if let pwd = getpwuid(targetUID) {
                    userDesc = String(cString: pwd.pointee.pw_name)
                } else {
                    userDesc = "UID \(targetUID)"
                }
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

            // Resolve username to UID if provided
            let targetUID: UInt32
            if let username = username {
                guard let pwd = getpwnam(username) else {
                    throw ValidationError("User not found: \(username)")
                }
                targetUID = pwd.pointee.pw_uid
            } else {
                targetUID = user!
            }

            let client = AgeSignalClient()
            do {
                try await client.connect(socketPath: socket)
            } catch {
                fputs("Error: Failed to connect to aged daemon: \(error)\n", stderr)
                throw ExitCode.failure
            }

            defer {
                Task {
                    await client.disconnect()
                }
            }

            do {
                try await client.removeBirthdate(for: targetUID)
            } catch {
                fputs("Error: Failed to remove birthdate: \(error)\n", stderr)
                throw ExitCode.failure
            }

            if json {
                print("""
                {"status":"ok","uid":\(targetUID)}
                """)
            } else {
                let userDesc: String
                if let pwd = getpwuid(targetUID) {
                    userDesc = String(cString: pwd.pointee.pw_name)
                } else {
                    userDesc = "UID \(targetUID)"
                }
                print("Birthdate removed for \(userDesc)")
            }
        }
    }
}
