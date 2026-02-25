/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CRctl
import Glibc

// MARK: - Subject

extension Rctl {
    /// A subject that resource limits can be applied to.
    public enum Subject: Sendable, Equatable {
        /// A specific process by PID.
        case process(pid_t)

        /// A user by UID.
        case user(uid_t)

        /// A user by name.
        case userName(String)

        /// A login class by name.
        case loginClass(String)

        /// A jail by JID.
        case jail(Int32)

        /// A jail by name.
        case jailName(String)

        /// The filter string representation for rctl.
        var filterString: String {
            switch self {
            case .process(let pid):
                return "process:\(pid)"
            case .user(let uid):
                return "user:\(uid)"
            case .userName(let name):
                return "user:\(name)"
            case .loginClass(let name):
                return "loginclass:\(name)"
            case .jail(let jid):
                return "jail:\(jid)"
            case .jailName(let name):
                return "jail:\(name)"
            }
        }

        /// The subject type name.
        var typeName: String {
            switch self {
            case .process:
                return "process"
            case .user, .userName:
                return "user"
            case .loginClass:
                return "loginclass"
            case .jail, .jailName:
                return "jail"
            }
        }

        /// The subject identifier.
        var identifier: String {
            switch self {
            case .process(let pid):
                return String(pid)
            case .user(let uid):
                return String(uid)
            case .userName(let name):
                return name
            case .loginClass(let name):
                return name
            case .jail(let jid):
                return String(jid)
            case .jailName(let name):
                return name
            }
        }
    }
}

// MARK: - Resource

extension Rctl {
    /// Resources that can be limited.
    public enum Resource: String, Sendable, CaseIterable {
        /// CPU time, in seconds.
        case cpuTime = "cputime"

        /// Maximum data segment size, in bytes.
        case dataSize = "datasize"

        /// Maximum stack size, in bytes.
        case stackSize = "stacksize"

        /// Maximum core dump size, in bytes.
        case coreDumpSize = "coredumpsize"

        /// Resident set size (physical memory), in bytes.
        case memoryUse = "memoryuse"

        /// Locked memory, in bytes.
        case memoryLocked = "memorylocked"

        /// Maximum number of processes.
        case maxProc = "maxproc"

        /// Maximum number of open files.
        case openFiles = "openfiles"

        /// Virtual memory size, in bytes.
        case vmemoryUse = "vmemoryuse"

        /// Maximum number of pseudo-terminals.
        case pseudoTerminals = "pseudoterminals"

        /// Swap space usage, in bytes.
        case swapUse = "swapuse"

        /// Maximum number of threads.
        case threads = "nthr"

        /// Number of queued SysV messages.
        case msgqQueued = "msgqqueued"

        /// SysV message queue size, in bytes.
        case msgqSize = "msgqsize"

        /// Number of SysV message queues.
        case nmsgq = "nmsgq"

        /// Number of SysV semaphores.
        case nsem = "nsem"

        /// Number of SysV semaphore operations.
        case nsemop = "nsemop"

        /// Number of SysV shared memory segments.
        case nshm = "nshm"

        /// SysV shared memory size, in bytes.
        case shmSize = "shmsize"

        /// Wallclock time, in seconds.
        case wallclock = "wallclock"

        /// CPU usage percentage (0-100 per CPU).
        case pcpu = "pcpu"

        /// Read bandwidth, in bytes per second.
        case readBps = "readbps"

        /// Write bandwidth, in bytes per second.
        case writeBps = "writebps"

        /// Read operations per second.
        case readIops = "readiops"

        /// Write operations per second.
        case writeIops = "writeiops"
    }
}

// MARK: - Action

extension Rctl {
    /// Action to take when a limit is exceeded.
    public enum Action: Sendable, Equatable {
        /// Deny the resource allocation (return error).
        case deny

        /// Log a warning via syslog.
        case log

        /// Send a notification via devctl.
        case devctl

        /// Throttle the process (for I/O resources).
        case throttle

        /// Send a signal to the process.
        case signal(Int32)

        /// The action string for rctl rules.
        var actionString: String {
            switch self {
            case .deny:
                return "deny"
            case .log:
                return "log"
            case .devctl:
                return "devctl"
            case .throttle:
                return "throttle"
            case .signal(let sig):
                return signalName(sig)
            }
        }

        /// Parse an action from a string.
        static func parse(_ str: String) -> Action? {
            switch str.lowercased() {
            case "deny":
                return .deny
            case "log":
                return .log
            case "devctl":
                return .devctl
            case "throttle":
                return .throttle
            default:
                // Check for signal names
                if let sig = parseSignalName(str) {
                    return .signal(sig)
                }
                return nil
            }
        }

        private func signalName(_ sig: Int32) -> String {
            switch sig {
            case SIGHUP: return "sighup"
            case SIGINT: return "sigint"
            case SIGQUIT: return "sigquit"
            case SIGKILL: return "sigkill"
            case SIGTERM: return "sigterm"
            case SIGSTOP: return "sigstop"
            case SIGUSR1: return "sigusr1"
            case SIGUSR2: return "sigusr2"
            case SIGXCPU: return "sigxcpu"
            case SIGXFSZ: return "sigxfsz"
            default: return "sig\(sig)"
            }
        }

        private static func parseSignalName(_ str: String) -> Int32? {
            switch str.lowercased() {
            case "sighup": return SIGHUP
            case "sigint": return SIGINT
            case "sigquit": return SIGQUIT
            case "sigkill": return SIGKILL
            case "sigterm": return SIGTERM
            case "sigstop": return SIGSTOP
            case "sigusr1": return SIGUSR1
            case "sigusr2": return SIGUSR2
            case "sigxcpu": return SIGXCPU
            case "sigxfsz": return SIGXFSZ
            default:
                if str.lowercased().hasPrefix("sig"),
                   let num = Int32(str.dropFirst(3)) {
                    return num
                }
                return nil
            }
        }
    }
}

// MARK: - Per

extension Rctl {
    /// How limits are applied (per what).
    public enum Per: String, Sendable {
        /// Per process.
        case process = "process"

        /// Per user.
        case user = "user"

        /// Per login class.
        case loginClass = "loginclass"

        /// Per jail.
        case jail = "jail"
    }
}

// MARK: - Rule

extension Rctl {
    /// A resource control rule.
    public struct Rule: Sendable, Equatable {
        /// The subject this rule applies to.
        public var subject: Subject

        /// The resource being limited.
        public var resource: Resource

        /// The action to take when the limit is exceeded.
        public var action: Action

        /// The limit amount.
        public var amount: UInt64

        /// How the limit is applied (optional, defaults to subject type).
        public var per: Per?

        /// Creates a new rule.
        public init(
            subject: Subject,
            resource: Resource,
            action: Action,
            amount: UInt64,
            per: Per? = nil
        ) {
            self.subject = subject
            self.resource = resource
            self.action = action
            self.amount = amount
            self.per = per
        }

        /// The rule string for rctl operations.
        var ruleString: String {
            var str = "\(subject.typeName):\(subject.identifier)"
            str += ":\(resource.rawValue)"
            str += ":\(action.actionString)=\(amount)"
            if let p = per {
                str += "/\(p.rawValue)"
            }
            return str
        }

        /// Parses a rule from a string.
        ///
        /// Rule format: `subject:id:resource:action=amount[/per]`
        init?(parsing str: String) {
            let parts = str.split(separator: ":", maxSplits: 3)
            guard parts.count == 4 else { return nil }

            // Parse subject
            let subjectType = String(parts[0])
            let subjectId = String(parts[1])

            switch subjectType {
            case "process":
                guard let pid = pid_t(subjectId) else { return nil }
                self.subject = .process(pid)
            case "user":
                if let uid = uid_t(subjectId) {
                    self.subject = .user(uid)
                } else {
                    self.subject = .userName(subjectId)
                }
            case "loginclass":
                self.subject = .loginClass(subjectId)
            case "jail":
                if let jid = Int32(subjectId) {
                    self.subject = .jail(jid)
                } else {
                    self.subject = .jailName(subjectId)
                }
            default:
                return nil
            }

            // Parse resource
            let resourceStr = String(parts[2])
            guard let resource = Resource(rawValue: resourceStr) else { return nil }
            self.resource = resource

            // Parse action=amount/per
            let actionPart = String(parts[3])
            let actionAmountParts = actionPart.split(separator: "=", maxSplits: 1)
            guard actionAmountParts.count == 2 else { return nil }

            let actionStr = String(actionAmountParts[0])
            guard let action = Action.parse(actionStr) else { return nil }
            self.action = action

            // Parse amount and optional per
            let amountPerStr = String(actionAmountParts[1])
            let amountPerParts = amountPerStr.split(separator: "/", maxSplits: 1)

            guard let amount = UInt64(amountPerParts[0]) else { return nil }
            self.amount = amount

            if amountPerParts.count == 2 {
                self.per = Per(rawValue: String(amountPerParts[1]))
            } else {
                self.per = nil
            }
        }
    }
}

extension Rctl.Rule: CustomStringConvertible {
    public var description: String {
        ruleString
    }
}
