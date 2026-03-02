/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FPC
import AgeSignal

// MARK: - RequestHandler

/// Handles incoming FPC requests from clients.
///
/// This actor processes age signal protocol messages, enforces authorization
/// based on peer credentials, and interacts with the storage layer.
actor RequestHandler {
    private let storage: AgeStorage
    private let verbose: Bool

    // MARK: - Initialization

    /// Creates a new request handler.
    ///
    /// - Parameters:
    ///   - storage: The storage actor for birthdate persistence
    ///   - verbose: Enable verbose logging
    init(storage: AgeStorage, verbose: Bool = false) {
        self.storage = storage
        self.verbose = verbose
    }

    // MARK: - Request Processing

    /// Handles a request from a client.
    ///
    /// - Parameters:
    ///   - message: The incoming FPC message
    ///   - peerCredentials: Credentials of the peer process
    ///   - endpoint: The endpoint to send the response on
    func handle(
        message: FPCMessage,
        peerCredentials: PeerCredentials,
        endpoint: FPCEndpoint
    ) async throws {
        // Decode the request
        let request: AgeSignalRequest
        do {
            request = try AgeSignalRequest.from(message: message)
        } catch {
            log("Invalid request from PID \(peerCredentials.pid): \(error)")
            let response = AgeSignalResponse.error(.invalidRequest)
            try await endpoint.send(response.toMessage(replyingTo: message))
            return
        }

        // Process based on request type
        let response = await processRequest(request, from: peerCredentials)
        try await endpoint.send(response.toMessage(replyingTo: message))
    }

    // MARK: - Authorization

    /// Checks if a request is authorized based on peer credentials.
    ///
    /// ## Authorization Rules
    ///
    /// - `queryOwn`: Always allowed—any process can query its own age bracket
    /// - `queryUser`: Allowed if:
    ///   - Caller is root (UID 0)
    ///   - Caller is querying their own UID
    ///   - Caller's primary GID matches target's primary GID (for family/shared accounts)
    /// - `setBirthdate`, `remove`: Root only—administrative operations
    ///
    /// The "same primary GID" rule enables household scenarios where a parent account
    /// can query children's age brackets without requiring root privileges.
    ///
    /// - Parameters:
    ///   - request: The request to authorize
    ///   - peer: The peer's credentials
    /// - Returns: `true` if authorized
    private func isAuthorized(request: AgeSignalRequest, peer: PeerCredentials) -> Bool {
        switch request {
        case .queryOwn:
            return true

        case .queryUser(let targetUID):
            // Own UID: always allowed
            if peer.uid == targetUID {
                return true
            }
            // Root: always allowed
            if peer.isRoot {
                return true
            }
            // Check if peer and target share the same primary GID
            // This requires looking up the target's GID from passwd
            if let targetGID = lookupPrimaryGID(uid: targetUID) {
                if peer.gid == targetGID {
                    return true
                }
            }
            return false

        case .setBirthdate, .remove:
            // Root only
            return peer.isRoot
        }
    }

    /// Looks up the primary GID for a UID from the passwd database.
    ///
    /// - Parameter uid: The user ID to look up
    /// - Returns: The primary group ID, or `nil` if user not found
    private func lookupPrimaryGID(uid: UInt32) -> gid_t? {
        guard let passwd = getpwuid(uid) else {
            return nil
        }
        return passwd.pointee.pw_gid
    }

    /// Checks if a user exists in the system.
    ///
    /// - Parameter uid: The user ID to check
    /// - Returns: `true` if the user exists
    private func userExists(uid: UInt32) -> Bool {
        getpwuid(uid) != nil
    }

    // MARK: - Request Processing

    /// Processes an authorized request.
    ///
    /// - Parameters:
    ///   - request: The decoded request
    ///   - peer: The peer's credentials
    /// - Returns: The response to send
    private func processRequest(_ request: AgeSignalRequest, from peer: PeerCredentials) async -> AgeSignalResponse {
        // Check authorization first
        guard isAuthorized(request: request, peer: peer) else {
            log("Permission denied: \(request) from UID \(peer.uid)")
            return .error(.permissionDenied)
        }

        do {
            switch request {
            case .queryOwn:
                return try await handleQueryOwn(peer: peer)

            case .queryUser(let uid):
                return try await handleQueryUser(uid: uid)

            case .setBirthdate(let uid, let birthdate):
                return try await handleSetBirthdate(uid: uid, birthdate: birthdate)

            case .remove(let uid):
                return try await handleRemove(uid: uid)
            }
        } catch {
            log("Error processing request: \(error)")
            return .error(.serviceUnavailable)
        }
    }

    // MARK: - Request Handlers

    /// Handles a query for the caller's own age bracket.
    private func handleQueryOwn(peer: PeerCredentials) async throws -> AgeSignalResponse {
        let uid = UInt32(peer.uid)
        log("Query own bracket for UID \(uid)")

        guard let bracket = try await storage.getBracket(uid: uid) else {
            return .error(.notSet)
        }

        return .success(bracket)
    }

    /// Handles a query for another user's age bracket.
    private func handleQueryUser(uid: UInt32) async throws -> AgeSignalResponse {
        log("Query bracket for UID \(uid)")

        // Check if user exists
        guard userExists(uid: uid) else {
            return .error(.unknownUser)
        }

        guard let bracket = try await storage.getBracket(uid: uid) else {
            return .error(.notSet)
        }

        return .success(bracket)
    }

    /// Handles setting a user's birthdate.
    private func handleSetBirthdate(uid: UInt32, birthdate: Birthdate) async throws -> AgeSignalResponse {
        log("Set birthdate for UID \(uid)")

        // Check if user exists
        guard userExists(uid: uid) else {
            return .error(.unknownUser)
        }

        try await storage.setBirthdate(uid: uid, birthdate: birthdate)
        let bracket = birthdate.currentBracket()
        return .success(bracket)
    }

    /// Handles removing a user's birthdate.
    private func handleRemove(uid: UInt32) async throws -> AgeSignalResponse {
        log("Remove birthdate for UID \(uid)")

        // Check if user exists (optional - could allow removing for non-existent users)
        guard userExists(uid: uid) else {
            return .error(.unknownUser)
        }

        try await storage.removeBirthdate(uid: uid)

        // Return ok status with a placeholder bracket (ignored by client)
        return AgeSignalResponse(status: .ok, bracket: nil)
    }

    // MARK: - Logging

    private func log(_ message: String) {
        if verbose {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("[\(timestamp)] \(message)")
        }
    }
}
