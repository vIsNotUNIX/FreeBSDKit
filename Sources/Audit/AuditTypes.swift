/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CAudit
import Glibc

/// Namespace for OpenBSM audit functionality.
public enum Audit {
    // MARK: - Type Aliases

    /// Audit user ID.
    public typealias AuditID = au_id_t

    /// Audit session ID.
    public typealias SessionID = au_asid_t

    /// Audit event number.
    public typealias EventNumber = au_event_t

    /// Audit class (bitmask).
    public typealias EventClass = au_class_t

    // MARK: - Audit Condition

    /// The current state of the audit subsystem.
    public enum Condition: Int32 {
        /// Audit state not set.
        case unset = 0
        /// Auditing is enabled.
        case auditing = 1
        /// Auditing is disabled (but can be enabled).
        case noAudit = 2
        /// Auditing is disabled in kernel config.
        case disabled = -1
    }

    /// Audit policy flags controlling what additional information is recorded.
    public struct Policy: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Continue after audit failure (vs. halt system).
        public static let continueOnFailure = Policy(rawValue: CAUDIT_POLICY_CNT)
        /// Halt system on audit failure.
        public static let haltOnFailure = Policy(rawValue: CAUDIT_POLICY_AHLT)
        /// Include command line arguments in exec events.
        public static let includeArgv = Policy(rawValue: CAUDIT_POLICY_ARGV)
        /// Include environment variables in exec events.
        public static let includeEnv = Policy(rawValue: CAUDIT_POLICY_ARGE)
        /// Include sequence numbers.
        public static let includeSequence = Policy(rawValue: CAUDIT_POLICY_SEQ)
        /// Include window data.
        public static let includeWindowData = Policy(rawValue: CAUDIT_POLICY_WINDATA)
        /// Include user token.
        public static let includeUser = Policy(rawValue: CAUDIT_POLICY_USER)
        /// Include group token.
        public static let includeGroup = Policy(rawValue: CAUDIT_POLICY_GROUP)
        /// Include trail token.
        public static let includeTrail = Policy(rawValue: CAUDIT_POLICY_TRAIL)
        /// Include path token.
        public static let includePath = Policy(rawValue: CAUDIT_POLICY_PATH)
    }

    // MARK: - Terminal ID

    /// Terminal identification for audit records.
    public struct TerminalID {
        /// Port/device number.
        public var port: UInt32
        /// Machine address (IPv4).
        public var machine: UInt32

        public init(port: UInt32 = 0, machine: UInt32 = 0) {
            self.port = port
            self.machine = machine
        }

        /// Creates a TerminalID from the C structure.
        internal init(from tid: au_tid_t) {
            self.port = tid.port
            self.machine = tid.machine
        }

        /// Converts to the C structure.
        internal func toC() -> au_tid_t {
            var tid = au_tid_t()
            tid.port = port
            tid.machine = machine
            return tid
        }
    }

    // MARK: - Audit Mask

    /// Audit preselection mask for success and failure events.
    public struct Mask: Sendable {
        /// Classes to audit on success.
        public var success: EventClass
        /// Classes to audit on failure.
        public var failure: EventClass

        public init(success: EventClass = 0, failure: EventClass = 0) {
            self.success = success
            self.failure = failure
        }

        /// Creates a Mask from the C structure.
        internal init(from mask: au_mask_t) {
            self.success = mask.am_success
            self.failure = mask.am_failure
        }

        /// Converts to the C structure.
        internal func toC() -> au_mask_t {
            var mask = au_mask_t()
            mask.am_success = success
            mask.am_failure = failure
            return mask
        }

        /// Mask that audits all events.
        public static let all = Mask(success: ~0, failure: ~0)

        /// Mask that audits no events.
        public static let none = Mask(success: 0, failure: 0)
    }

    // MARK: - Audit Info

    /// Basic audit information for a process.
    public struct AuditInfo {
        /// Audit user ID.
        public var auditID: AuditID
        /// Audit preselection mask.
        public var mask: Mask
        /// Terminal ID.
        public var terminalID: TerminalID
        /// Audit session ID.
        public var sessionID: SessionID

        public init(
            auditID: AuditID = CAUDIT_DEFAUDITID,
            mask: Mask = .none,
            terminalID: TerminalID = TerminalID(),
            sessionID: SessionID = 0
        ) {
            self.auditID = auditID
            self.mask = mask
            self.terminalID = terminalID
            self.sessionID = sessionID
        }

        /// Creates AuditInfo from the C structure.
        internal init(from info: auditinfo_t) {
            self.auditID = info.ai_auid
            self.mask = Mask(from: info.ai_mask)
            self.terminalID = TerminalID(from: info.ai_termid)
            self.sessionID = info.ai_asid
        }

        /// Converts to the C structure.
        internal func toC() -> auditinfo_t {
            var info = auditinfo_t()
            info.ai_auid = auditID
            info.ai_mask = mask.toC()
            info.ai_termid = terminalID.toC()
            info.ai_asid = sessionID
            return info
        }
    }

    // MARK: - Queue Control

    /// Audit queue control parameters.
    public struct QueueControl {
        /// High watermark (max records before blocking).
        public var highWater: Int32
        /// Low watermark (records to unblock).
        public var lowWater: Int32
        /// Maximum audit record size.
        public var bufferSize: Int32
        /// Queue delay (not currently used).
        public var delay: Int32
        /// Minimum filesystem free space percentage.
        public var minFree: Int32

        public init(
            highWater: Int32 = Int32(AQ_HIWATER),
            lowWater: Int32 = Int32(AQ_LOWATER),
            bufferSize: Int32 = Int32(AQ_BUFSZ),
            delay: Int32 = 20,
            minFree: Int32 = Int32(AU_FS_MINFREE)
        ) {
            self.highWater = highWater
            self.lowWater = lowWater
            self.bufferSize = bufferSize
            self.delay = delay
            self.minFree = minFree
        }

        /// Creates QueueControl from the C structure.
        internal init(from qctrl: au_qctrl_t) {
            self.highWater = qctrl.aq_hiwater
            self.lowWater = qctrl.aq_lowater
            self.bufferSize = qctrl.aq_bufsz
            self.delay = qctrl.aq_delay
            self.minFree = qctrl.aq_minfree
        }

        /// Converts to the C structure.
        internal func toC() -> au_qctrl_t {
            var qctrl = au_qctrl_t()
            qctrl.aq_hiwater = highWater
            qctrl.aq_lowater = lowWater
            qctrl.aq_bufsz = bufferSize
            qctrl.aq_delay = delay
            qctrl.aq_minfree = minFree
            return qctrl
        }
    }

    // MARK: - Audit Statistics

    /// Audit subsystem statistics.
    public struct Statistics {
        /// Version number.
        public let version: UInt32
        /// Number of audit events.
        public let eventCount: UInt32
        /// Records generated.
        public let generated: Int32
        /// Non-attributable records.
        public let nonAttributable: Int32
        /// Kernel records.
        public let kernel: Int32
        /// audit(2) records.
        public let audit: Int32
        /// auditctl(2) records.
        public let auditctl: Int32
        /// Records enqueued.
        public let enqueued: Int32
        /// Records written.
        public let written: Int32
        /// Write blocks.
        public let writeBlocked: Int32
        /// Read blocks.
        public let readBlocked: Int32
        /// Records dropped.
        public let dropped: Int32
        /// Total size of records.
        public let totalSize: Int32
        /// Memory used.
        public let memoryUsed: UInt32

        /// Creates Statistics from the C structure.
        internal init(from stat: au_stat_t) {
            self.version = stat.as_version
            self.eventCount = stat.as_numevent
            self.generated = stat.as_generated
            self.nonAttributable = stat.as_nonattrib
            self.kernel = stat.as_kernel
            self.audit = stat.as_audit
            self.auditctl = stat.as_auditctl
            self.enqueued = stat.as_enqueue
            self.written = stat.as_written
            self.writeBlocked = stat.as_wblocked
            self.readBlocked = stat.as_rblocked
            self.dropped = stat.as_dropped
            self.totalSize = stat.as_totalsize
            self.memoryUsed = stat.as_memused
        }
    }
}

// MARK: - Error Type

extension Audit {
    /// Errors that can occur during audit operations.
    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        /// The errno value.
        public let errno: Int32

        /// Creates an error from an errno value.
        public init(errno: Int32) {
            self.errno = errno
        }

        public var description: String {
            String(cString: strerror(errno))
        }

        // Common error cases
        public static let notPermitted = Error(errno: EPERM)
        public static let noSuchProcess = Error(errno: ESRCH)
        public static let invalidArgument = Error(errno: EINVAL)
        public static let notSupported = Error(errno: EOPNOTSUPP)
        public static let noMemory = Error(errno: ENOMEM)
    }
}
