/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CCapsicum
import Glibc

/// Errors that can occur when working with Capsicum capabilities.
public enum CapsicumError: Error, Equatable, Sendable {

    /// Capsicum is not supported on the current system.
    case capsicumUnsupported

    /// Casper (Capsicum sandbox helpers) is not supported on the current system.
    case casperUnsupported

    /// The file descriptor provided was invalid.
    case badFileDescriptor

    /// One or more arguments (flags, options) were invalid.
    case invalidArgument

    /// Attempted to expand capability rights, which is not allowed.
    case notCapable

    /// Operation not permitted in capability mode.
    case capabilityModeViolation

    /// Other errno not covered by specific cases.
    case underlyingFailure(errno: Int32)

    public static func errorFromErrno(_ code: Int32, isCasper: Bool = false) -> CapsicumError {
        switch code {
        case ENOSYS:
            return isCasper ? .casperUnsupported : .capsicumUnsupported
        
        case EBADF:
            return .badFileDescriptor
        
        case EINVAL:
            return .invalidArgument
        
        case ENOTCAPABLE:
            return .notCapable
        
        case ECAPMODE:
            return .capabilityModeViolation
        
        default:
            return .underlyingFailure(errno: code)
        }
    }
}

/// Errors that can occur when limiting fcntl commands with Capsicum.
public enum CapsicumFcntlError: Error {
    /// The file descriptor was not valid (`EBADF`).
    case invalidDescriptor
    
    /// An invalid flag was passed (`EINVAL`).
    case invalidFlag
    
    /// The requested rights would expand the current set of allowed fcntl commands (`ENOTCAPABLE`).
    case notCapable
    
    /// An unexpected underlying errno value.
    case system(errno: Int32)
}

/// Errors that can occur when querying or interpreting the list of
/// allowed `ioctl(2)` commands on a file descriptor under Capsicum.
public enum CapsicumIoctlError: Error, Equatable {
    /// The file descriptor is invalid (EBADF).
    case invalidDescriptor

    /// The commands buffer pointer was invalid (EFAULT).
    case badBuffer

    /// The buffer was too small for the allowed ioctl list.
    case insufficientBuffer(expected: Int)

    /// All ioctls are explicitly allowed (no limit applied).
    case allIoctlsAllowed

    /// Some other underlying errno error.
    case system(errno: Int32)
}