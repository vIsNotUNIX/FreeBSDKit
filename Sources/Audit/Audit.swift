/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CAudit
import Glibc

extension Audit {
    /// Checks if auditing is currently enabled.
    ///
    /// - Returns: `true` if auditing is active.
    public static var isEnabled: Bool {
        let state = caudit_get_state()
        return state == CAUDIT_AUC_AUDITING
    }

    /// Gets the current audit condition.
    ///
    /// - Returns: The current audit condition.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func condition() throws -> Condition {
        var cond: Int32 = 0
        if caudit_get_cond(&cond) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return Condition(rawValue: cond) ?? .disabled
    }

    /// Sets the audit condition.
    ///
    /// - Parameter condition: The new audit condition.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges (typically root).
    public static func set(condition: Condition) throws {
        var cond = condition.rawValue
        if caudit_set_cond(&cond) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Gets the current audit policy.
    ///
    /// - Returns: The current policy flags.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func policy() throws -> Policy {
        var policy: Int32 = 0
        if caudit_get_policy(&policy) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return Policy(rawValue: policy)
    }

    /// Sets the audit policy.
    ///
    /// - Parameter policy: The new policy flags.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges.
    public static func set(policy: Policy) throws {
        var pol = policy.rawValue
        if caudit_set_policy(&pol) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Gets the audit queue control parameters.
    ///
    /// - Returns: The current queue control settings.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func queueControl() throws -> QueueControl {
        var qctrl = au_qctrl_t()
        if caudit_get_qctrl(&qctrl, MemoryLayout<au_qctrl_t>.size) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return QueueControl(from: qctrl)
    }

    /// Sets the audit queue control parameters.
    ///
    /// - Parameter queueControl: The new queue control settings.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges.
    public static func set(queueControl: QueueControl) throws {
        var qctrl = queueControl.toC()
        if caudit_set_qctrl(&qctrl, MemoryLayout<au_qctrl_t>.size) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Gets the audit statistics.
    ///
    /// - Returns: Current audit statistics.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func statistics() throws -> Statistics {
        var stats = au_stat_t()
        if caudit_get_stat(&stats, MemoryLayout<au_stat_t>.size) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return Statistics(from: stats)
    }
}

// MARK: - Process Audit Info

extension Audit {
    /// Gets the audit user ID for the current process.
    ///
    /// - Returns: The audit user ID.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func auditID() throws -> AuditID {
        var auid: au_id_t = 0
        if caudit_getauid(&auid) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return auid
    }

    /// Sets the audit user ID for the current process.
    ///
    /// - Parameter auditID: The new audit user ID.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Can only be set once per session, requires privileges.
    public static func set(auditID: AuditID) throws {
        var auid = auditID
        if caudit_setauid(&auid) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Gets the audit information for the current process.
    ///
    /// - Returns: The audit information.
    /// - Throws: `Audit.Error` if the operation fails.
    public static func auditInfo() throws -> AuditInfo {
        var info = auditinfo_t()
        if caudit_getaudit(&info) != 0 {
            throw Error(errno: Glibc.errno)
        }
        return AuditInfo(from: info)
    }

    /// Sets the audit information for the current process.
    ///
    /// - Parameter info: The new audit information.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges.
    public static func set(auditInfo info: AuditInfo) throws {
        var cInfo = info.toC()
        if caudit_setaudit(&cInfo) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }
}

// MARK: - Event Submission

extension Audit {
    /// Submits a simple audit record for the current process.
    ///
    /// This is a high-level convenience function that creates and submits
    /// a complete audit record with subject token, text token, and return token.
    ///
    /// - Parameters:
    ///   - event: The audit event number (AUE_* constant).
    ///   - message: A text message describing the event.
    ///   - success: `true` if the operation succeeded, `false` if it failed.
    ///   - error: The error code (errno) if the operation failed.
    /// - Throws: `Audit.Error` if the submission fails.
    ///
    /// Example:
    /// ```swift
    /// try Audit.submit(
    ///     event: AUE_login,
    ///     message: "User login successful",
    ///     success: true
    /// )
    /// ```
    public static func submit(
        event: EventNumber,
        message: String,
        success: Bool,
        error: Int32 = 0
    ) throws {
        let status: Int8 = success ? 0 : 1
        let result = message.withCString { cMessage in
            caudit_submit(Int16(event), CAUDIT_DEFAUDITID, status, error, cMessage)
        }
        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }

    /// Submits a simple audit record with a custom audit ID.
    ///
    /// - Parameters:
    ///   - event: The audit event number.
    ///   - auditID: The audit user ID for the record.
    ///   - message: A text message describing the event.
    ///   - success: `true` if the operation succeeded.
    ///   - error: The error code if the operation failed.
    /// - Throws: `Audit.Error` if the submission fails.
    public static func submit(
        event: EventNumber,
        auditID: AuditID,
        message: String,
        success: Bool,
        error: Int32 = 0
    ) throws {
        let status: Int8 = success ? 0 : 1
        let result = message.withCString { cMessage in
            caudit_submit(Int16(event), auditID, status, error, cMessage)
        }
        if result != 0 {
            throw Error(errno: Glibc.errno)
        }
    }
}
