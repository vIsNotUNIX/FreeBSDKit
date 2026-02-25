/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CAudit
import Glibc

// MARK: - Audit Record Builder

extension Audit {
    /// A builder for constructing custom audit records.
    ///
    /// Use this when you need more control over audit record contents
    /// than the simple `submit()` function provides.
    ///
    /// Example:
    /// ```swift
    /// var record = try Audit.Record(event: AUE_custom)
    /// try record.addSubjectToken()  // Current process as subject
    /// try record.addText("Custom operation performed")
    /// try record.addPath("/path/to/file")
    /// try record.addReturn(success: true)
    /// try record.commit()
    /// ```
    public struct Record {
        private let descriptor: Int32
        private let event: EventNumber
        private var committed: Bool = false

        /// Creates a new audit record builder.
        ///
        /// - Parameter event: The audit event number for this record.
        /// - Throws: `Audit.Error` if the record cannot be created.
        public init(event: EventNumber) throws {
            let desc = caudit_open()
            if desc < 0 {
                throw Error(errno: Glibc.errno)
            }
            self.descriptor = desc
            self.event = event
        }

        /// Adds a subject token for the current process.
        ///
        /// Every audit record should have a subject token identifying
        /// who performed the action.
        ///
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addSubjectToken() throws {
            guard let token = caudit_to_me() else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a custom subject token with specific identity information.
        ///
        /// - Parameters:
        ///   - auditID: The audit user ID.
        ///   - effectiveUID: The effective user ID.
        ///   - effectiveGID: The effective group ID.
        ///   - realUID: The real user ID.
        ///   - realGID: The real group ID.
        ///   - pid: The process ID.
        ///   - sessionID: The audit session ID.
        ///   - terminalID: The terminal ID.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addSubjectToken(
            auditID: AuditID,
            effectiveUID: uid_t,
            effectiveGID: gid_t,
            realUID: uid_t,
            realGID: gid_t,
            pid: pid_t,
            sessionID: SessionID,
            terminalID: TerminalID
        ) throws {
            var tid = terminalID.toC()
            guard let token = caudit_to_subject32(
                auditID, effectiveUID, effectiveGID,
                realUID, realGID, pid, sessionID, &tid
            ) else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a text token to the record.
        ///
        /// - Parameter text: The text message to include.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addText(_ text: String) throws {
            let token = text.withCString { cText in
                caudit_to_text(cText)
            }
            guard let token else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a path token to the record.
        ///
        /// - Parameter path: The file path to include.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addPath(_ path: String) throws {
            let token = path.withCString { cPath in
                caudit_to_path(cPath)
            }
            guard let token else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a 32-bit argument token to the record.
        ///
        /// - Parameters:
        ///   - number: The argument number (1-based).
        ///   - name: A description of the argument.
        ///   - value: The 32-bit argument value.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addArgument32(
            number: Int8,
            name: String,
            value: UInt32
        ) throws {
            let token = name.withCString { cName in
                caudit_to_arg32(number, cName, value)
            }
            guard let token else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a 64-bit argument token to the record.
        ///
        /// - Parameters:
        ///   - number: The argument number (1-based).
        ///   - name: A description of the argument.
        ///   - value: The 64-bit argument value.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addArgument64(
            number: Int8,
            name: String,
            value: UInt64
        ) throws {
            let token = name.withCString { cName in
                caudit_to_arg64(number, cName, value)
            }
            guard let token else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds an exit token to the record.
        ///
        /// - Parameters:
        ///   - returnValue: The return value.
        ///   - error: The error code (errno).
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addExit(returnValue: Int32, error: Int32) throws {
            guard let token = caudit_to_exit(returnValue, error) else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds a return token to the record.
        ///
        /// Every audit record should end with a return token indicating
        /// success or failure.
        ///
        /// - Parameters:
        ///   - success: `true` if the operation succeeded.
        ///   - value: The return value (typically 0 for success).
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addReturn(success: Bool, value: UInt32 = 0) throws {
            let status: Int8 = success ? 0 : 1
            guard let token = caudit_to_return32(status, value) else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Adds an opaque data token to the record.
        ///
        /// - Parameter data: The raw data to include.
        /// - Throws: `Audit.Error` if the token cannot be added.
        public mutating func addOpaque(_ data: [UInt8]) throws {
            guard data.count <= UInt16.max else {
                throw Error.invalidArgument
            }
            let token = data.withUnsafeBufferPointer { buffer in
                caudit_to_opaque(
                    buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: data.count) { $0 },
                    UInt16(data.count)
                )
            }
            guard let token else {
                throw Error(errno: Glibc.errno)
            }
            if caudit_write(descriptor, token) < 0 {
                caudit_free_token(token)
                throw Error(errno: Glibc.errno)
            }
        }

        /// Commits the audit record to the audit trail.
        ///
        /// After calling this method, the record is written and the
        /// builder cannot be used again.
        ///
        /// - Throws: `Audit.Error` if the record cannot be committed.
        public mutating func commit() throws {
            guard !committed else { return }
            if caudit_close(descriptor, CAUDIT_TO_WRITE, Int16(event)) < 0 {
                throw Error(errno: Glibc.errno)
            }
            committed = true
        }

        /// Abandons the audit record without writing it.
        ///
        /// Use this if you need to discard a partially built record.
        public mutating func abandon() {
            guard !committed else { return }
            _ = caudit_close(descriptor, CAUDIT_TO_NO_WRITE, Int16(event))
            committed = true
        }
    }
}
