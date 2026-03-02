/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Glibc
import FPC
import AgeSignal
import Casper
import Audit

// MARK: - Audit Event Numbers

/// BSM audit event numbers for aged operations.
///
/// These use the AUE_audit_user event (32767) which is specifically designated
/// for application-generated audit records. This avoids conflicts with
/// system-defined events while staying within the valid UInt16 range.
///
/// For production deployment with distinct event numbers, register custom
/// events in `/etc/security/audit_event` in the range 32768-65535.
private enum AgedAuditEvent {
    /// Generic user event for all aged operations.
    /// The specific operation is identified in the message text.
    static let userEvent: Audit.EventNumber = 32767  // AUE_audit_user
}

// MARK: - RequestHandler

/// Handles incoming FPC requests from clients.
///
/// This actor processes age signal protocol messages, enforces authorization
/// based on peer credentials, and interacts with the storage layer.
///
/// ## Capsicum Capability Mode
///
/// The handler is designed to work within Capsicum capability mode:
/// - Uses `CasperPwd` for UID-to-username lookups
/// - Uses `CasperSyslog` for logging
/// - Uses capability-based `AgeStorage` for persistence
actor RequestHandler {
    private let storage: AgeStorage
    private let pwdService: CasperPwd
    private let logService: CasperSyslog
    private let verbose: Bool

    // MARK: - Initialization

    /// Creates a new request handler.
    ///
    /// - Parameters:
    ///   - storage: The storage actor for birthdate persistence
    ///   - pwdService: Casper password service for UID lookups (ownership transferred)
    ///   - logService: Casper syslog service for logging (ownership transferred)
    ///   - verbose: Enable verbose logging
    init(
        storage: AgeStorage,
        pwdService: consuming CasperPwd,
        logService: consuming CasperSyslog,
        verbose: Bool = false
    ) {
        self.storage = storage
        self.pwdService = pwdService
        self.logService = logService
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
            if let targetEntry = pwdService.getpwuid(targetUID) {
                if peer.gid == targetEntry.gid {
                    return true
                }
            }
            return false

        case .setBirthdate, .remove:
            // Root only
            return peer.isRoot
        }
    }

    /// Checks if a user exists in the system.
    ///
    /// - Parameter uid: The user ID to check
    /// - Returns: `true` if the user exists
    private func userExists(uid: UInt32) -> Bool {
        pwdService.getpwuid(uid) != nil
    }

    /// Gets the username for a UID.
    ///
    /// - Parameter uid: The user ID
    /// - Returns: The username, or nil if not found
    private func username(for uid: UInt32) -> String? {
        pwdService.getpwuid(uid)?.name
    }

    // MARK: - Request Handlers

    /// Processes an authorized request.
    ///
    /// - Parameters:
    ///   - request: The decoded request
    ///   - peer: The peer's credentials
    /// - Returns: The response to send
    private func processRequest(_ request: AgeSignalRequest, from peer: PeerCredentials) async -> AgeSignalResponse {
        // Check authorization first
        guard isAuthorized(request: request, peer: peer) else {
            logAuth("Permission denied: \(request) from UID \(peer.uid) PID \(peer.pid)")

            // Submit audit event for permission denial
            auditPermissionDenied(request: request, peer: peer)

            return .error(.permissionDenied)
        }

        do {
            switch request {
            case .queryOwn:
                return try await handleQueryOwn(peer: peer)

            case .queryUser(let uid):
                return try await handleQueryUser(uid: uid)

            case .setBirthdate(let uid, let birthdate):
                return try await handleSetBirthdate(uid: uid, birthdate: birthdate, peer: peer)

            case .remove(let uid):
                return try await handleRemove(uid: uid, peer: peer)
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
    private func handleSetBirthdate(uid: UInt32, birthdate: Birthdate, peer: PeerCredentials) async throws -> AgeSignalResponse {
        let user = username(for: uid) ?? "UID \(uid)"
        logAuth("Set birthdate for \(user) by UID \(peer.uid) PID \(peer.pid)")

        // Check if user exists
        guard userExists(uid: uid) else {
            return .error(.unknownUser)
        }

        try await storage.setBirthdate(uid: uid, birthdate: birthdate)
        let bracket = birthdate.currentBracket()

        // Submit audit event
        auditSetBirthdate(uid: uid, bracket: bracket, peer: peer, success: true)

        return .success(bracket)
    }

    /// Handles removing a user's birthdate.
    private func handleRemove(uid: UInt32, peer: PeerCredentials) async throws -> AgeSignalResponse {
        let user = username(for: uid) ?? "UID \(uid)"
        logAuth("Remove birthdate for \(user) by UID \(peer.uid) PID \(peer.pid)")

        // Check if user exists
        guard userExists(uid: uid) else {
            return .error(.unknownUser)
        }

        try await storage.removeBirthdate(uid: uid)

        // Submit audit event
        auditRemoveBirthdate(uid: uid, peer: peer, success: true)

        // Return ok status with no bracket
        return AgeSignalResponse(status: .ok, bracket: nil)
    }

    // MARK: - Audit Events

    /// Submits a BSM audit event for birthdate set operations.
    private func auditSetBirthdate(uid: UInt32, bracket: AgeBracket, peer: PeerCredentials, success: Bool) {
        let user = username(for: uid) ?? "UID \(uid)"
        let message = "aged: SET_BIRTHDATE for \(user) (bracket=\(bracket)) by PID \(peer.pid) UID \(peer.uid)"

        do {
            try Audit.submit(
                event: AgedAuditEvent.userEvent,
                message: message,
                success: success
            )
        } catch {
            // Audit submission failure is not fatal - log and continue
            log("Failed to submit audit event: \(error)")
        }
    }

    /// Submits a BSM audit event for birthdate remove operations.
    private func auditRemoveBirthdate(uid: UInt32, peer: PeerCredentials, success: Bool) {
        let user = username(for: uid) ?? "UID \(uid)"
        let message = "aged: REMOVE_BIRTHDATE for \(user) by PID \(peer.pid) UID \(peer.uid)"

        do {
            try Audit.submit(
                event: AgedAuditEvent.userEvent,
                message: message,
                success: success
            )
        } catch {
            log("Failed to submit audit event: \(error)")
        }
    }

    /// Submits a BSM audit event for permission denied.
    private func auditPermissionDenied(request: AgeSignalRequest, peer: PeerCredentials) {
        let message = "aged: PERMISSION_DENIED for \(request) from PID \(peer.pid) UID \(peer.uid)"

        do {
            try Audit.submit(
                event: AgedAuditEvent.userEvent,
                message: message,
                success: false,
                error: EACCES
            )
        } catch {
            log("Failed to submit audit event: \(error)")
        }
    }

    // MARK: - Logging

    /// Logs a message to syslog (daemon facility).
    private func log(_ message: String) {
        if verbose {
            logService.info(message)
        }
    }

    /// Logs a security-relevant message to syslog (auth facility).
    private func logAuth(_ message: String) {
        logService.log(.notice, facility: .auth, message)
    }
}
