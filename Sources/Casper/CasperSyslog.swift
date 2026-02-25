/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCasper
import FreeBSDKit
import Glibc

/// Syslog service for Capsicum sandboxes.
///
/// `CasperSyslog` wraps a Casper syslog service channel and provides type-safe
/// Swift interfaces to syslog functions that work within capability mode.
///
/// ## Usage
///
/// ```swift
/// // Before entering capability mode
/// let casper = try CasperChannel.create()
/// let syslog = try CasperSyslog(casper: casper)
///
/// // Open syslog
/// syslog.openlog(ident: "myapp", options: [.pid], facility: .daemon)
///
/// // Enter capability mode
/// try Capsicum.enter()
///
/// // Log messages
/// syslog.log(.info, "Application started")
/// syslog.log(.warning, "Something happened")
/// ```
public struct CasperSyslog: ~Copyable, Sendable {
    private let channel: CasperChannel

    /// Creates a syslog service from a Casper channel.
    ///
    /// - Parameter casper: The main Casper channel.
    /// - Throws: `CasperError.serviceOpenFailed` if the syslog service cannot be opened.
    public init(casper: consuming CasperChannel) throws {
        self.channel = try casper.open(.syslog)
    }

    /// Creates a syslog service from an existing service channel.
    ///
    /// - Parameter channel: A channel already connected to the syslog service.
    public init(channel: consuming CasperChannel) {
        self.channel = channel
    }

    /// Syslog options.
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Log the process ID with each message.
        public static let pid = Options(rawValue: LOG_PID)
        /// Log to console if unable to send to syslog.
        public static let cons = Options(rawValue: LOG_CONS)
        /// Open connection immediately.
        public static let odelay = Options(rawValue: LOG_ODELAY)
        /// Delay open until first log.
        public static let ndelay = Options(rawValue: LOG_NDELAY)
        /// Don't wait for child processes.
        public static let nowait = Options(rawValue: LOG_NOWAIT)
        /// Log to stderr as well.
        public static let perror = Options(rawValue: LOG_PERROR)
    }

    /// Syslog facility.
    public enum Facility: Int32, Sendable {
        case kern = 0       // LOG_KERN
        case user = 8       // LOG_USER
        case mail = 16      // LOG_MAIL
        case daemon = 24    // LOG_DAEMON
        case auth = 32      // LOG_AUTH
        case syslog = 40    // LOG_SYSLOG
        case lpr = 48       // LOG_LPR
        case news = 56      // LOG_NEWS
        case uucp = 64      // LOG_UUCP
        case cron = 72      // LOG_CRON
        case authpriv = 80  // LOG_AUTHPRIV
        case ftp = 88       // LOG_FTP
        case local0 = 128   // LOG_LOCAL0
        case local1 = 136   // LOG_LOCAL1
        case local2 = 144   // LOG_LOCAL2
        case local3 = 152   // LOG_LOCAL3
        case local4 = 160   // LOG_LOCAL4
        case local5 = 168   // LOG_LOCAL5
        case local6 = 176   // LOG_LOCAL6
        case local7 = 184   // LOG_LOCAL7
    }

    /// Syslog priority level.
    public enum Priority: Int32, Sendable {
        /// System is unusable.
        case emerg = 0      // LOG_EMERG
        /// Action must be taken immediately.
        case alert = 1      // LOG_ALERT
        /// Critical conditions.
        case crit = 2       // LOG_CRIT
        /// Error conditions.
        case err = 3        // LOG_ERR
        /// Warning conditions.
        case warning = 4    // LOG_WARNING
        /// Normal but significant condition.
        case notice = 5     // LOG_NOTICE
        /// Informational.
        case info = 6       // LOG_INFO
        /// Debug-level messages.
        case debug = 7      // LOG_DEBUG
    }

    /// Opens a connection to the syslog daemon.
    ///
    /// - Parameters:
    ///   - ident: String prepended to every message.
    ///   - options: Logging options.
    ///   - facility: Default facility for messages.
    public func openlog(ident: String, options: Options = [], facility: Facility = .user) {
        ident.withCString { identPtr in
            channel.withUnsafeChannel { chan in
                ccasper_openlog(chan, identPtr, options.rawValue, facility.rawValue)
            }
        }
    }

    /// Closes the connection to the syslog daemon.
    public func closelog() {
        channel.withUnsafeChannel { chan in
            ccasper_closelog(chan)
        }
    }

    /// Sets the log priority mask.
    ///
    /// - Parameter mask: The priority mask.
    /// - Returns: The previous mask value.
    @discardableResult
    public func setlogmask(_ mask: Int32) -> Int32 {
        channel.withUnsafeChannel { chan in
            ccasper_setlogmask(chan, mask)
        }
    }

    /// Logs a message.
    ///
    /// - Parameters:
    ///   - priority: The message priority.
    ///   - message: The message to log.
    public func log(_ priority: Priority, _ message: String) {
        message.withCString { messagePtr in
            channel.withUnsafeChannel { chan in
                ccasper_syslog(chan, priority.rawValue, messagePtr)
            }
        }
    }

    /// Logs a message with facility.
    ///
    /// - Parameters:
    ///   - priority: The message priority.
    ///   - facility: The facility for this message.
    ///   - message: The message to log.
    public func log(_ priority: Priority, facility: Facility, _ message: String) {
        let combined = priority.rawValue | facility.rawValue
        message.withCString { messagePtr in
            channel.withUnsafeChannel { chan in
                ccasper_syslog(chan, combined, messagePtr)
            }
        }
    }

    /// Convenience methods for logging at specific levels.
    public func emergency(_ message: String) { log(.emerg, message) }
    public func alert(_ message: String) { log(.alert, message) }
    public func critical(_ message: String) { log(.crit, message) }
    public func error(_ message: String) { log(.err, message) }
    public func warning(_ message: String) { log(.warning, message) }
    public func notice(_ message: String) { log(.notice, message) }
    public func info(_ message: String) { log(.info, message) }
    public func debug(_ message: String) { log(.debug, message) }
}
