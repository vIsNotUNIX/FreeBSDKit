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

/// Individual Capsicum capability rights for file descriptors.
///
/// Use `CapabilityRight` in conjunction with `CapabilityRightSet` for limiting rights on a descriptor.
public enum CapabilityRight: Sendable {
    /// Permit read operations such as `read(2)`, `pread(2)`, etc.
    case read
    
    /// Permit write operations such as `write(2)`, `pwrite(2)`, etc.
    case write
    
    /// Permit seeking on the file descriptor (e.g., `lseek(2)`).
    case seek
    
    /// Permit accepting connections (`accept(2)` / `accept4(2)`).
    case accept
    
    /// Permit ACL validity checking (`acl_valid_fd_np(3)`).
    case aclCheck
    
    /// Permit ACL deletion (`acl_delete_fd_np(3)`).
    case aclDelete
    
    /// Permit ACL retrieval (`acl_get_fd(3)`, `acl_get_fd_np(3)`).
    case aclGet
    
    /// Permit setting ACLs (`acl_set_fd(3)`, `acl_set_fd_np(3)`).
    case aclSet
    
    /// Permit binding a socket (`bind(2)`).
    case bind
    
    /// Permit directory-relative binding (`bindat(2)`).
    case bindat
    
    /// Permit changing file flags relative to a directory (`chflagsat(2)`).
    case chflagsat
    
    /// Permit connecting a socket (`connect(2)`).
    case connect
    
    /// Permit directory-relative connect (`connectat(2)`).
    case connectat
    
    /// Permit creation (`openat(2)` with `O_CREAT`).
    case create
    
    /// Permit asynchronous event notification (`select(2)`, `poll(2)`, `kevent(2)`).
    case event
    
    /// Permit removing extended attributes (`extattr_delete_fd(2)`).
    case extattrDelete
    
    /// Permit getting extended attributes (`extattr_get_fd(2)`).
    case extattrGet
    
    /// Permit listing extended attributes (`extattr_list_fd(2)`).
    case extattrList
    
    /// Permit setting extended attributes (`extattr_set_fd(2)`).
    case extattrSet
    
    /// Permit changing working directory (`fchdir(2)`).
    case fchdir
    
    /// Permit changing file flags (`fchflags(2)`).
    case fchflags
    
    /// Permit changing file mode (`fchmod(2)`).
    case fchmod
    
    /// Permit directory-relative changing mode (`fchmodat(2)`).
    case fchmodat
    
    /// Permit changing file owner (`fchown(2)`).
    case fchown
    
    /// Permit directory-relative changing owner (`fchownat(2)`).
    case fchownat
    
    /// Permit changing root of a process (`fchroot(2)`).
    case fchroot
    
    /// Permit `fcntl(2)` operations on the descriptor.
    /// Note: only some commands require this right, and they can be
    /// further limited via `cap_fcntls_limit(2)`. :contentReference[oaicite:3]{index=3}
    case fcntl
    
    /// Permit executing file descriptors (`fexecve(2)`).
    case fexecve
    
    /// Permit advisory locking (`flock(2)`).
    case flock
    
    /// Permit querying path configuration (`fpathconf(2)`).
    case fpathconf
    
    /// Permit file system check operations (UFS background fsck).
    case fsck
    
    /// Permit getting file status (`fstat(2)`).
    case fstat
    
    /// Permit directory-relative stat (`fstatat(2)`).
    case fstatat
    
    /// Permit file system status (`fstatfs(2)`).
    case fstatfs
    
    /// Permit synchronizing file data (`fsync(2)`).
    case fsync
    
    /// Permit truncating files (`ftruncate(2)`).
    case ftruncate
    
    /// Permit updating file access/modification times (`futimes(2)`).
    case futimes
    
    /// Permit directory-relative time updates (`futimesat(2)`).
    case futimesat
    
    /// Permit peer address retrieval (`getpeername(2)`).
    case getpeername
    
    /// Permit socket name retrieval (`getsockname(2)`).
    case getsockname
    
    /// Permit getting socket options (`getsockopt(2)`).
    case getsockopt
    
    /// Permit adding an inotify watch (`inotify_add_watch(2)`).
    case inotifyAdd
    
    /// Permit removing an inotify watch (`inotify_rm_watch(2)`).
    case inotifyRm
    
    /// Permit general `ioctl(2)` usage.
    /// Specific allowed ioctls can be further restricted with
    /// `cap_ioctls_limit(2)`. :contentReference[oaicite:4]{index=4}
    case ioctl
    
    /// Permit creating an event queue (`kqueue(2)`).
    case kqueue
    
    /// Permit modifying kqueue event list (`kevent(2)` changelist).
    case kqueueChange
    
    /// Permit monitoring events on a kqueue descriptor.
    case kqueueEvent
    
    /// Permit linking within a source directory (`linkat(2)`).
    case linkatSource
    
    /// Permit linking within a target directory (`linkat(2)`).
    case linkatTarget
    
    /// Permit listening for connections (`listen(2)`).
    case listen
    
    /// Permit directory lookup (`CAP_LOOKUP`), used as a base right
    case lookup
    
    /// Permit getting MAC label (`mac_get_fd(3)`).
    case macGet
    
    /// Permit setting MAC label (`mac_set_fd(3)`).
    case macSet
    
    /// Permit creating a directory (`mkdirat(2)`).
    case mkdirat
    
    /// Permit creating a FIFO (`mkfifoat(2)`).
    case mkfifoat
    
    /// Permit creating a node (`mknodat(2)`).
    case mknodat
    
    /// Permit basic `mmap(2)` without protection (`PROT_NONE`).
    case mmap
    
    /// Permit `mmap(2)` with read protection.
    case mmapR

    /// Permit read/write/prot combined rights for `mmap(2)`.
    case mmapRW

    /// Permit read/write/exec combinations for `mmap(2)`.
    case mmapRWX

    /// Permit combined read/exec for `mmap(2)`.
    case mmapRX

    /// Permit `mmap(2)` with write protection.
    case mmapW

    /// Permit combined write/exec protections.
    case mmapWX

    /// Permit `mmap(2)` with exec protection.
    case mmapX
    
    /// Permit retrieving child process IDs (`pdgetpid(2)`).
    case pdgetpid

    /// Permit sending a process kill (`pdkill(2)`).
    case pdkill

    /// Permit peeling off an SCTP association (`sctp_peeloff(2)`).
    case peeloff
    
    /// Permit reading from a descriptor (`CAP_PREAD` alias).
    case pread

    /// Permit writing to a descriptor (`CAP_PWRITE` alias).
    case pwrite
    
    /// Permit getting semaphore value (`sem_getvalue(3)`).
    case semGetValue

    /// Permit posting a semaphore (`sem_post(3)`).
    case semPost

    /// Permit waiting on a semaphore (`sem_wait(3)`).
    case semWait
    
    /// Permit sending operations on sockets (`CAP_SEND` alias).
    case send
    
    /// Permit setting socket options (`setsockopt(2)`).
    case setsockopt
    
    /// Permit shutting down a socket (`shutdown(2)`).
    case shutdown
    
    /// Permit creating symbolic links (`symlinkat(2)`).
    case symlinkat
    
    /// Permit TTY hook configuration (`CAP_TTYHOOK`).
    case ttyhook
    
    /// Permit unlinking directory entries (`unlinkat(2)`).
    case unlinkat

    /// Maps this Swift enum case to the corresponding C
    /// `ccapsicum_right_bridge` value used by the Capsicum bridge functions.
    @inline(__always)
    var bridged: ccapsicum_right_bridge {
        switch self {
        case .read:               return CCAP_RIGHT_READ
        case .write:              return CCAP_RIGHT_WRITE
        case .seek:               return CCAP_RIGHT_SEEK
        case .accept:             return CCAP_RIGHT_ACCEPT
        case .aclCheck:           return CCAP_RIGHT_ACL_CHECK
        case .aclDelete:          return CCAP_RIGHT_ACL_DELETE
        case .aclGet:             return CCAP_RIGHT_ACL_GET
        case .aclSet:             return CCAP_RIGHT_ACL_SET
        case .bind:               return CCAP_RIGHT_BIND
        case .bindat:             return CCAP_RIGHT_BINDAT
        case .chflagsat:          return CCAP_RIGHT_CHFLAGSAT
        case .connect:            return CCAP_RIGHT_CONNECT
        case .connectat:          return CCAP_RIGHT_CONNECTAT
        case .create:             return CCAP_RIGHT_CREATE
        case .event:              return CCAP_RIGHT_EVENT
        case .extattrDelete:      return CCAP_RIGHT_EXTATTR_DELETE
        case .extattrGet:         return CCAP_RIGHT_EXTATTR_GET
        case .extattrList:        return CCAP_RIGHT_EXTATTR_LIST
        case .extattrSet:         return CCAP_RIGHT_EXTATTR_SET
        case .fchdir:             return CCAP_RIGHT_FCHDIR
        case .fchflags:           return CCAP_RIGHT_FCHFLAGS
        case .fchmod:             return CCAP_RIGHT_FCHMOD
        case .fchmodat:           return CCAP_RIGHT_FCHMODAT
        case .fchown:             return CCAP_RIGHT_FCHOWN
        case .fchownat:           return CCAP_RIGHT_FCHOWNAT
        case .fchroot:            return CCAP_RIGHT_FCHROOT
        case .fcntl:              return CCAP_RIGHT_FCNTL
        case .fexecve:            return CCAP_RIGHT_FEXECVE
        case .flock:              return CCAP_RIGHT_FLOCK
        case .fpathconf:          return CCAP_RIGHT_FPATHCONF
        case .fsck:               return CCAP_RIGHT_FSCK
        case .fstat:              return CCAP_RIGHT_FSTAT
        case .fstatat:            return CCAP_RIGHT_FSTATAT
        case .fstatfs:            return CCAP_RIGHT_FSTATFS
        case .fsync:              return CCAP_RIGHT_FSYNC
        case .ftruncate:          return CCAP_RIGHT_FTRUNCATE
        case .futimes:            return CCAP_RIGHT_FUTIMES
        case .futimesat:          return CCAP_RIGHT_FUTIMESAT
        case .getpeername:        return CCAP_RIGHT_GETPEERNAME
        case .getsockname:        return CCAP_RIGHT_GETSOCKNAME
        case .getsockopt:         return CCAP_RIGHT_GETSOCKOPT
        case .inotifyAdd:         return CCAP_RIGHT_INOTIFY_ADD
        case .inotifyRm:          return CCAP_RIGHT_INOTIFY_RM
        case .ioctl:              return CCAP_RIGHT_IOCTL
        case .kqueue:             return CCAP_RIGHT_KQUEUE
        case .kqueueChange:       return CCAP_RIGHT_KQUEUE_CHANGE
        case .kqueueEvent:        return CCAP_RIGHT_KQUEUE_EVENT
        case .linkatSource:       return CCAP_RIGHT_LINKAT_SOURCE
        case .linkatTarget:       return CCAP_RIGHT_LINKAT_TARGET
        case .listen:             return CCAP_RIGHT_LISTEN
        case .lookup:             return CCAP_RIGHT_LOOKUP
        case .macGet:             return CCAP_RIGHT_MAC_GET
        case .macSet:             return CCAP_RIGHT_MAC_SET
        case .mkdirat:            return CCAP_RIGHT_MKDIRAT
        case .mkfifoat:           return CCAP_RIGHT_MKFIFOAT
        case .mknodat:            return CCAP_RIGHT_MKNODAT
        case .mmap:               return CCAP_RIGHT_MMAP
        case .mmapR:              return CCAP_RIGHT_MMAP_R
        case .mmapRW:             return CCAP_RIGHT_MMAP_RW
        case .mmapRWX:            return CCAP_RIGHT_MMAP_RWX
        case .mmapRX:             return CCAP_RIGHT_MMAP_RX
        case .mmapW:              return CCAP_RIGHT_MMAP_W
        case .mmapWX:             return CCAP_RIGHT_MMAP_WX
        case .mmapX:              return CCAP_RIGHT_MMAP_X
        case .pdgetpid:           return CCAP_RIGHT_PDGETPID
        case .pdkill:             return CCAP_RIGHT_PDKILL
        case .peeloff:            return CCAP_RIGHT_PEELOFF
        case .pread:              return CCAP_RIGHT_PREAD
        case .pwrite:             return CCAP_RIGHT_PWRITE
        case .semGetValue:        return CCAP_RIGHT_SEM_GETVALUE
        case .semPost:            return CCAP_RIGHT_SEM_POST
        case .semWait:            return CCAP_RIGHT_SEM_WAIT
        case .send:               return CCAP_RIGHT_SEND
        case .setsockopt:         return CCAP_RIGHT_SETSOCKOPT
        case .shutdown:           return CCAP_RIGHT_SHUTDOWN
        case .symlinkat:          return CCAP_RIGHT_SYMLINKAT
        case .ttyhook:            return CCAP_RIGHT_TTYHOOK
        case .unlinkat:           return CCAP_RIGHT_UNLINKAT
        }
    }
}