/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import FreeBSDKit

// MARK: - RlimitResource

extension Rctl {

    /// A resource enforced by `setrlimit(2)` and queryable via
    /// `getrlimitusage(2)`.
    ///
    /// These map directly onto the `RLIMIT_*` constants in
    /// `<sys/resource.h>`. They are distinct from ``Rctl/Resource`` (which
    /// names the rctl(4) string-keyed resources) and intentionally so:
    /// `getrlimitusage(2)` is the rlimit-side accountant, while rctl(4)
    /// is the racct-side one.
    public enum RlimitResource: Int32, Sendable, CaseIterable {
        case cpu      = 0  // RLIMIT_CPU
        case fsize    = 1  // RLIMIT_FSIZE
        case data     = 2  // RLIMIT_DATA
        case stack    = 3  // RLIMIT_STACK
        case core     = 4  // RLIMIT_CORE
        case rss      = 5  // RLIMIT_RSS
        case memlock  = 6  // RLIMIT_MEMLOCK
        case nproc    = 7  // RLIMIT_NPROC
        case nofile   = 8  // RLIMIT_NOFILE
        case sbsize   = 9  // RLIMIT_SBSIZE
        case vmem     = 10 // RLIMIT_VMEM (alias: RLIMIT_AS)
        case npts     = 11 // RLIMIT_NPTS
        case swap     = 12 // RLIMIT_SWAP
        case kqueues  = 13 // RLIMIT_KQUEUES
        case umtxp    = 14 // RLIMIT_UMTXP
        case pipebuf  = 15 // RLIMIT_PIPEBUF
    }

    /// Flags for ``Rctl/limitUsage(of:flags:)``.
    public struct RlimitUsageFlags: OptionSet, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }

        /// Account against the effective UID instead of the real UID.
        ///
        /// By default the kernel reports usage charged to the real UID,
        /// matching how rlimits are accounted. Pass this flag to query
        /// against the effective UID.
        public static let effectiveUID = RlimitUsageFlags(rawValue: GETRLIMITUSAGE_EUID)
    }

    // MARK: - getrlimitusage(2)

    /// Query the current process's usage of an `rlimit`-tracked resource.
    ///
    /// This wraps `getrlimitusage(2)` (FreeBSD 14.2+). It reports how much
    /// of a given `RLIMIT_*` resource the calling process has consumed,
    /// which lets a process see how close it is to its own limits without
    /// scraping `kvm`/`procstat`.
    ///
    /// Some resources are not accounted (only enforced at allocation
    /// time) — notably `RLIMIT_FSIZE` and `RLIMIT_CORE`. Querying those
    /// throws `BSDError` with `ENXIO`.
    ///
    /// - Parameters:
    ///   - resource: The `RLIMIT_*` resource to query.
    ///   - flags: Optional behavior flags.
    /// - Returns: Current usage as `rlim_t` (a 64-bit unsigned integer).
    /// - Throws: `BSDError` on failure (`EINVAL` for unknown resource,
    ///   `ENXIO` for unaccounted resource).
    public static func limitUsage(
        of resource: RlimitResource,
        flags: RlimitUsageFlags = []
    ) throws -> rlim_t {
        var usage: rlim_t = 0
        let r = Glibc.getrlimitusage(UInt32(resource.rawValue), flags.rawValue, &usage)
        if r != 0 {
            try BSDError.throwErrno(errno)
        }
        return usage
    }
}
