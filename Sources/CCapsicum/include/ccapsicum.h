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

#pragma once

#include <sys/capsicum.h>
#include <sys/caprights.h>
#include <capsicum_helpers.h>

/**
 * @enum ccapsicum_right_bridge
 * @brief Individual Capsicum capability rights.
 *
 * Each constant represents a specific operation that can be permitted on a
 * file descriptor when in Capsicum capability mode.
 *
 * @remarks These rights are used with functions like `cap_rights_limit()`,
 * `cap_rights_is_set()`, and related Capsicum APIs.
 * Note: The underlying C macros are not directly callable from Swift, so a Swift bridge
 * (`CapsicumRight` and `CapsicumRightSet`) is used to provide type-safe
 * access in Swift.
 */
typedef enum {
    CCAP_RIGHT_ACCEPT,
    CCAP_RIGHT_ACL_CHECK,
    CCAP_RIGHT_ACL_DELETE,
    CCAP_RIGHT_ACL_GET,
    CCAP_RIGHT_ACL_SET,
    CCAP_RIGHT_BIND,
    CCAP_RIGHT_BINDAT,
    CCAP_RIGHT_CHFLAGSAT,
    CCAP_RIGHT_CONNECT,
    CCAP_RIGHT_CONNECTAT,
    CCAP_RIGHT_CREATE,
    CCAP_RIGHT_EVENT,
    CCAP_RIGHT_EXTATTR_DELETE,
    CCAP_RIGHT_EXTATTR_GET,
    CCAP_RIGHT_EXTATTR_LIST,
    CCAP_RIGHT_EXTATTR_SET,
    CCAP_RIGHT_FCHDIR,
    CCAP_RIGHT_FCHFLAGS,
    CCAP_RIGHT_FCHMOD,
    CCAP_RIGHT_FCHMODAT,
    CCAP_RIGHT_FCHOWN,
    CCAP_RIGHT_FCHOWNAT,
    CCAP_RIGHT_FCHROOT,
    CCAP_RIGHT_FCNTL,
    CCAP_RIGHT_FEXECVE,
    CCAP_RIGHT_FLOCK,
    CCAP_RIGHT_FPATHCONF,
    CCAP_RIGHT_FSCK,
    CCAP_RIGHT_FSTAT,
    CCAP_RIGHT_FSTATAT,
    CCAP_RIGHT_FSTATFS,
    CCAP_RIGHT_FSYNC,
    CCAP_RIGHT_FTRUNCATE,
    CCAP_RIGHT_FUTIMES,
    CCAP_RIGHT_FUTIMESAT,
    CCAP_RIGHT_GETPEERNAME,
    CCAP_RIGHT_GETSOCKNAME,
    CCAP_RIGHT_GETSOCKOPT,
    CCAP_RIGHT_INOTIFY_ADD,
    CCAP_RIGHT_INOTIFY_RM,
    CCAP_RIGHT_IOCTL,
    CCAP_RIGHT_KQUEUE,
    CCAP_RIGHT_KQUEUE_CHANGE,
    CCAP_RIGHT_KQUEUE_EVENT,
    CCAP_RIGHT_LINKAT_SOURCE,
    CCAP_RIGHT_LINKAT_TARGET,
    CCAP_RIGHT_LISTEN,
    CCAP_RIGHT_LOOKUP,
    CCAP_RIGHT_MAC_GET,
    CCAP_RIGHT_MAC_SET,
    CCAP_RIGHT_MKDIRAT,
    CCAP_RIGHT_MKFIFOAT,
    CCAP_RIGHT_MKNODAT,
    CCAP_RIGHT_MMAP,
    CCAP_RIGHT_MMAP_R,
    CCAP_RIGHT_MMAP_RW,
    CCAP_RIGHT_MMAP_RWX,
    CCAP_RIGHT_MMAP_RX,
    CCAP_RIGHT_MMAP_W,
    CCAP_RIGHT_MMAP_WX,
    CCAP_RIGHT_MMAP_X,
    CCAP_RIGHT_PDGETPID,
    CCAP_RIGHT_PDKILL,
    CCAP_RIGHT_PEELOFF,
    CCAP_RIGHT_PREAD,
    CCAP_RIGHT_PWRITE,
    CCAP_RIGHT_SEM_GETVALUE,
    CCAP_RIGHT_SEM_POST,
    CCAP_RIGHT_SEM_WAIT,
    CCAP_RIGHT_SEND,
    CCAP_RIGHT_SETSOCKOPT,
    CCAP_RIGHT_SHUTDOWN,
    CCAP_RIGHT_SYMLINKAT,
    CCAP_RIGHT_TTYHOOK,
    CCAP_RIGHT_UNLINKAT,
    CCAP_RIGHT_READ,
    CCAP_RIGHT_WRITE,
    CCAP_RIGHT_SEEK,
} ccapsicum_right_bridge;


// MARK: Bridging functions.

/// Selects the correct Capsicum capability at runtime.
///
/// This function resolves a platform-appropriate capability value
/// from a bridged representation.
///
/// @param r A bridged Capsicum right.
/// @return The resolved 64-bit capability value.
inline uint64_t
ccapsicum_selector(ccapsicum_right_bridge r);

/// Limits the rights on a file descriptor.
///
/// Applies the given Capsicum rights to the file descriptor, restricting
/// future operations.
///
/// @param fd The file descriptor to limit.
/// @param rights The rights to apply.
/// @return 0 on success, or -1 on failure with errno set.
inline int
ccapsicum_cap_limit(int fd, const cap_rights_t *rights);

/// Initializes a Capsicum rights structure.
///
/// Sets the rights structure to an empty, valid state.
///
/// @param rights A pointer to a rights structure.
/// @return The initialized rights structure.
inline cap_rights_t *
ccapsicum_rights_init(cap_rights_t *rights);

/// Merges two Capsicum rights sets.
///
/// The resulting rights contain the union of both inputs.
///
/// @param rightA The destination rights set.
/// @param rightB The rights to merge into `rightA`.
/// @return The merged rights structure.
inline cap_rights_t *
ccapsicum_cap_rights_merge(cap_rights_t *rightA,
                           const cap_rights_t *rightB);

/// Sets a specific capability right.
///
/// @param right The rights structure to modify.
/// @param cap The capability to set.
/// @return The updated rights structure.
inline cap_rights_t *
ccapsicum_cap_set(cap_rights_t *right,
                   ccapsicum_right_bridge cap);

/// Tests whether a capability is present in a rights set.
///
/// @param rights The rights structure to test.
/// @param right The capability to check.
/// @return `true` if the right is present, otherwise `false`.
inline bool
ccapsicum_right_is_set(const cap_rights_t *rights,
                       ccapsicum_right_bridge right);

/// Validates a Capsicum rights structure.
///
/// @param rights The rights structure to validate.
/// @return `true` if the rights are valid, otherwise `false`.
inline bool
ccapsicum_rights_valid(cap_rights_t *rights);

/// Removes the given capability if it is present.
///
/// @param rights The rights structure to modify.
/// @param right The capability to clear.
inline void
ccapsicum_rights_clear(cap_rights_t *rights,
                       ccapsicum_right_bridge right);

/// Tests whether one rights set contains another.
///
/// @param big The superset of rights.
/// @param little The subset of rights.
/// @return `true` if `big` contains all rights in `little`.
inline bool
ccapsicum_rights_contains(const cap_rights_t *big,
                          const cap_rights_t *little);

/// Removes rights from a destination set.
///
/// All rights present in `src` are removed from `dst`.
///
/// @param dst The destination rights structure.
/// @param src The rights to remove.
/// @return The updated destination rights structure.
inline cap_rights_t *
ccapsicum_rights_remove(cap_rights_t *dst,
                        const cap_rights_t *src);

/// Limits the allowed ioctl commands on a file descriptor.
///
/// @param fd The file descriptor to restrict.
/// @param cmds An array of allowed ioctl commands.
/// @param ncmds The number of commands in `cmds`.
/// @return 0 on success, or -1 on failure.
inline int
ccapsicum_limit_ioctls(int fd,
                       const unsigned long *cmds,
                       size_t ncmds);

/// Retrieves the allowed ioctl commands for a file descriptor.
///
/// @param fd The file descriptor to query.
/// @param cmds A buffer to receive ioctl commands.
/// @param maxcmds The maximum number of commands to write.
/// @return The number of commands written, or -1 on failure.
inline ssize_t
ccapsicum_get_ioctls(int fd,
                     unsigned long *cmds,
                     size_t maxcmds);

/// Limits the allowed fcntl operations on a file descriptor.
///
/// @param fd The file descriptor to restrict.
/// @param fcntlrights A bitmask of allowed fcntl operations.
/// @return 0 on success, or -1 on failure.
inline int
ccapsicum_limit_fcntls(int fd,
                       uint32_t fcntlrights);

/// Retrieves the allowed fcntl operations for a file descriptor.
///
/// @param fd The file descriptor to query.
/// @param fcntlrightsp A pointer to receive the fcntl rights bitmask.
/// @return 0 on success, or -1 on failure.
inline int
ccapsicum_get_fcntls(int fd,
                     uint32_t *fcntlrightsp);
