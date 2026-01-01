import CCapsicum

/// Individual Capability Rights.
/// `man rights(4)`
public enum CapabilityRight {
    case read
    case write
    case seek
    case accept
    case aclCheck
    case aclDelete
    case aclGet
    case aclSet
    case bind
    case bindat
    case chflagsat
    case connect
    case connectat
    case create
    case event
    case extattrDelete
    case extattrGet
    case extattrList
    case extattrSet
    case fchdir
    case fchflags
    case fchmod
    case fchmodat
    case fchown
    case fchownat
    case fchroot
    case fcntl
    case fexecve
    case flock
    case fpathconf
    case fsck
    case fstat
    case fstatat
    case fstatfs
    case fsync
    case ftruncate
    case futimes
    case futimesat
    case getpeername
    case getsockname
    case getsockopt
    case inotifyAdd
    case inotifyRm
    case ioctl
    case kqueue
    case kqueueChange
    case kqueueEvent
    case linkatSource
    case linkatTarget
    case listen
    case lookup
    case macGet
    case macSet
    case mkdirat
    case mkfifoat
    case mknodat
    case mmap
    case mmapR
    case mmapRW
    case mmapRWX
    case mmapRX
    case mmapW
    case mmapWX
    case mmapX
    case pdgetpid
    case pdkill
    case peeloff
    case pread
    case pwrite
    case semGetValue
    case semPost
    case semWait
    case send
    case setsockopt
    case shutdown
    case symlinkat
    case ttyhook
    case unlinkat

    /// Bridges a capability to it's `ccapsicum_right_bridge`
    /// 
    /// Discussion. A small runtime performance hit make the code more succinct
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