/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import FPC
import Descriptors
import Capabilities

// MARK: - AgeSignalClient

/// Client for querying age signals from the aged daemon.
///
/// This is the primary API for applications to query age brackets.
/// The client connects to the aged daemon via FPC (Unix domain socket)
/// and provides simple methods to query age brackets.
///
/// ## Example
///
/// ```swift
/// let client = AgeSignalClient()
/// try await client.connect()
///
/// let result = try await client.queryOwnBracket()
/// switch result {
/// case .bracket(let bracket):
///     print("Your age bracket: \(bracket)")
/// case .notSet:
///     print("Age not configured")
/// case .permissionDenied:
///     print("Permission denied")
/// case .unknownUser:
///     print("User not found")
/// case .error(let error):
///     print("Error: \(error)")
/// }
///
/// await client.disconnect()
/// ```
public actor AgeSignalClient {
    private var endpoint: FPCEndpoint?
    private var isConnected: Bool = false

    // MARK: - Initialization

    /// Creates a new age signal client.
    ///
    /// Call `connect()` before using the client.
    public init() {}

    // MARK: - Connection

    /// Connects to the age signal daemon.
    ///
    /// - Parameter socketPath: Path to the daemon socket. Defaults to `/var/run/aged.sock`.
    /// - Throws: `AgeSignalError.connectionFailed` if the connection cannot be established.
    public func connect(socketPath: String = AgeSignalProtocol.defaultSocketPath) async throws {
        guard !isConnected else { return }

        do {
            let ep = try FPCClient.connect(path: socketPath)
            await ep.start()
            self.endpoint = ep
            self.isConnected = true
        } catch {
            throw AgeSignalError.connectionFailed(underlying: error)
        }
    }

    /// Connects to the age signal daemon via a directory descriptor.
    ///
    /// This is useful for Capsicum-sandboxed applications that have a capability
    /// for the directory containing the socket but cannot use absolute paths.
    ///
    /// - Parameters:
    ///   - directory: A directory descriptor containing the socket.
    ///   - path: The relative path to the socket within the directory.
    /// - Throws: `AgeSignalError.connectionFailed` if the connection cannot be established.
    public func connect<D: DirectoryDescriptor>(
        at directory: borrowing D,
        path: String
    ) async throws where D: ~Copyable {
        guard !isConnected else { return }

        do {
            let ep = try FPCClient.connect(at: directory, path: path)
            await ep.start()
            self.endpoint = ep
            self.isConnected = true
        } catch {
            throw AgeSignalError.connectionFailed(underlying: error)
        }
    }

    /// Disconnects from the daemon.
    public func disconnect() async {
        guard isConnected, let ep = endpoint else { return }
        await ep.stop()
        self.endpoint = nil
        self.isConnected = false
    }

    // MARK: - Query Operations

    /// Queries the age bracket for the current user (own UID).
    ///
    /// This is the primary API for applications. It returns the age bracket
    /// of the user running the calling process, as determined by the daemon
    /// from peer credentials.
    ///
    /// - Parameter timeout: Optional timeout for the request.
    /// - Returns: The result of the query.
    /// - Throws: `AgeSignalError` if the query fails.
    public func queryOwnBracket(timeout: Duration = .seconds(5)) async throws -> AgeSignalResult {
        let request = AgeSignalRequest.queryOwn
        let response = try await sendRequest(request, timeout: timeout)
        return response.toResult()
    }

    /// Queries the age bracket for a specific user.
    ///
    /// This requires elevated privileges:
    /// - Root (UID 0) can query any user.
    /// - Users in the same primary group can query each other.
    /// - Other queries will return `permissionDenied`.
    ///
    /// - Parameters:
    ///   - uid: The user ID to query.
    ///   - timeout: Optional timeout for the request.
    /// - Returns: The result of the query.
    /// - Throws: `AgeSignalError` if the query fails.
    public func queryBracket(for uid: UInt32, timeout: Duration = .seconds(5)) async throws -> AgeSignalResult {
        let request = AgeSignalRequest.queryUser(uid: uid)
        let response = try await sendRequest(request, timeout: timeout)
        return response.toResult()
    }

    // MARK: - Administrative Operations

    /// Sets the birthdate for a user.
    ///
    /// This requires root privileges.
    ///
    /// - Parameters:
    ///   - birthdate: The birthdate to set.
    ///   - uid: The user ID to set the birthdate for.
    ///   - timeout: Optional timeout for the request.
    /// - Throws: `AgeSignalError` if the operation fails.
    public func setBirthdate(_ birthdate: Birthdate, for uid: UInt32, timeout: Duration = .seconds(5)) async throws {
        let request = AgeSignalRequest.setBirthdate(uid: uid, birthdate: birthdate)
        let response = try await sendRequest(request, timeout: timeout)

        if response.status != .ok {
            switch response.status {
            case .permissionDenied:
                throw AgeSignalError.permissionDenied("Root privileges required to set birthdate")
            case .unknownUser:
                throw AgeSignalError.userNotFound("UID \(uid)")
            default:
                throw AgeSignalError.protocolError("Unexpected status: \(response.status)")
            }
        }
    }

    /// Removes the birthdate for a user.
    ///
    /// This requires root privileges.
    ///
    /// - Parameters:
    ///   - uid: The user ID to remove the birthdate for.
    ///   - timeout: Optional timeout for the request.
    /// - Throws: `AgeSignalError` if the operation fails.
    public func removeBirthdate(for uid: UInt32, timeout: Duration = .seconds(5)) async throws {
        let request = AgeSignalRequest.remove(uid: uid)
        let response = try await sendRequest(request, timeout: timeout)

        if response.status != .ok && response.status != .notSet {
            switch response.status {
            case .permissionDenied:
                throw AgeSignalError.permissionDenied("Root privileges required to remove birthdate")
            case .unknownUser:
                throw AgeSignalError.userNotFound("UID \(uid)")
            default:
                throw AgeSignalError.protocolError("Unexpected status: \(response.status)")
            }
        }
    }

    // MARK: - Internal

    private func sendRequest(_ request: AgeSignalRequest, timeout: Duration) async throws -> AgeSignalResponse {
        guard isConnected, let ep = endpoint else {
            throw AgeSignalError.notConnected
        }

        let message = request.toMessage()

        do {
            let reply = try await ep.request(message, timeout: timeout)

            guard reply.id == .ageResponse else {
                if reply.id == .ageError {
                    let errorMsg = String(data: reply.payload, encoding: .utf8) ?? "Unknown error"
                    throw AgeSignalError.protocolError(errorMsg)
                }
                throw AgeSignalError.invalidResponse
            }

            return try AgeSignalResponse.decode(from: reply.payload)
        } catch let error as FPCError {
            switch error {
            case .timeout:
                throw AgeSignalError.timeout
            case .disconnected:
                self.isConnected = false
                throw AgeSignalError.notConnected
            default:
                throw AgeSignalError.protocolError(error.localizedDescription)
            }
        }
    }
}
