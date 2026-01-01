#pragma once

#include <sys/capsicum.h>
#include <sys/caprights.h>

// MARK: Right Bridge.C MACROs are not callable from Swift, so we bridge.
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

// Selects the correct capability at runtime.
uint64_t inline
ccapsicum_selector(ccapsicum_right_bridge r);

// MARK: Cap Rights Functions
inline int 
ccapsicum_cap_limit(int fd, const cap_rights_t* rights);

inline cap_rights_t*
ccapsicum_rights_init(cap_rights_t *rights);

inline cap_rights_t*
ccapsicum_cap_rights_merge(cap_rights_t* rightA, const cap_rights_t* rightB);

inline cap_rights_t*
ccaspsicum_cap_set(cap_rights_t* right, ccapsicum_right_bridge cap);

inline bool
ccapsicum_right_is_set(const cap_rights_t* rights, ccapsicum_right_bridge right);

inline bool
ccapsicum_rights_valid(cap_rights_t* rights);

inline void
ccapsicum_rights_clear(cap_rights_t* rights, ccapsicum_right_bridge right);

inline bool
ccapsicum_rights_contains(const cap_rights_t *big, const cap_rights_t *little);

inline cap_rights_t*
ccapsicum_rights_remove(cap_rights_t *dst, const cap_rights_t *src);