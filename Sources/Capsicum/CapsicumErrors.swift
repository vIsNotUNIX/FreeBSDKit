/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import CCapsicum
import Glibc

/// Errors that can occur when working with Capsicum capabilities.
public enum CapsicumError: Error, Equatable {

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

    static func errorFromErrno(_ code: Int32, isCasper: Bool = false) -> CapsicumError {
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
///
public enum CapsicumIoctlError: Error {
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