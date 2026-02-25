/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CCASPER_H
#define CCASPER_H

/*
 * C bridge for FreeBSD's Casper (libcasper) API.
 *
 * Casper provides services to sandboxed (capability mode) processes
 * that don't have the rights to perform certain operations themselves.
 * Services run in separate sandboxed processes and communicate via
 * Unix domain sockets.
 */

#include <sys/types.h>
#include <sys/nv.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <netdb.h>

/* Define HAVE_CASPER before including libcasper.h to get full API */
#define HAVE_CASPER 1
#define WITH_CASPER 1

#include <sys/stat.h>

#include <libcasper.h>
#include <casper/cap_dns.h>
#include <casper/cap_sysctl.h>
#include <casper/cap_pwd.h>
#include <casper/cap_grp.h>
#include <casper/cap_fileargs.h>
#include <casper/cap_syslog.h>
#include <casper/cap_net.h>
#include <casper/cap_netdb.h>

/*
 * Service name constants for cap_service_open()
 */
static const char * const CCASPER_SERVICE_DNS = "system.dns";
static const char * const CCASPER_SERVICE_SYSCTL = "system.sysctl";
static const char * const CCASPER_SERVICE_PWD = "system.pwd";
static const char * const CCASPER_SERVICE_GRP = "system.grp";
static const char * const CCASPER_SERVICE_FILEARGS = "system.fileargs";
static const char * const CCASPER_SERVICE_SYSLOG = "system.syslog";

/*
 * DNS type limit constants
 */
static const char * const CCASPER_DNS_TYPE_ADDR2NAME = "ADDR2NAME";
static const char * const CCASPER_DNS_TYPE_NAME2ADDR = "NAME2ADDR";

/*
 * Sysctl access flags
 */
static const int CCASPER_SYSCTL_READ = CAP_SYSCTL_READ;
static const int CCASPER_SYSCTL_WRITE = CAP_SYSCTL_WRITE;
static const int CCASPER_SYSCTL_RDWR = CAP_SYSCTL_RDWR;
static const int CCASPER_SYSCTL_RECURSIVE = CAP_SYSCTL_RECURSIVE;

/* CTL_MAXNAME constant for sysctl MIB */
static const int CCASPER_CTL_MAXNAME = CTL_MAXNAME;

/*
 * Core channel functions - use void* for Swift OpaquePointer compatibility
 */

/* Initialize the main casper channel */
static inline void *ccasper_init(void) {
    return (void *)cap_init();
}

/* Open a named service */
static inline void *ccasper_service_open(void *casper, const char *name) {
    return (void *)cap_service_open((cap_channel_t *)casper, name);
}

/* Close a channel */
static inline void ccasper_close(void *chan) {
    cap_close((cap_channel_t *)chan);
}

/* Clone a channel */
static inline void *ccasper_clone(void *chan) {
    return (void *)cap_clone((cap_channel_t *)chan);
}

/* Get underlying socket for kqueue/select/poll */
static inline int ccasper_sock(void *chan) {
    return cap_sock((cap_channel_t *)chan);
}

/* Wrap an existing socket as a channel */
static inline void *ccasper_wrap(int sock, int flags) {
    return (void *)cap_wrap(sock, flags);
}

/* Unwrap a channel to get the socket */
static inline int ccasper_unwrap(void *chan, int *flags) {
    return cap_unwrap((cap_channel_t *)chan, flags);
}

/* Limit services that can be opened */
static inline int ccasper_service_limit(
    void *chan,
    const char * const *names,
    size_t nnames
) {
    return cap_service_limit((cap_channel_t *)chan, names, nnames);
}

/*
 * DNS service wrappers
 */
static inline int ccasper_getaddrinfo(
    void *chan,
    const char *hostname,
    const char *servname,
    const struct addrinfo *hints,
    struct addrinfo **res
) {
    return cap_getaddrinfo((cap_channel_t *)chan, hostname, servname, hints, res);
}

static inline int ccasper_getnameinfo(
    void *chan,
    const struct sockaddr *sa,
    socklen_t salen,
    char *host,
    size_t hostlen,
    char *serv,
    size_t servlen,
    int flags
) {
    return cap_getnameinfo((cap_channel_t *)chan, sa, salen, host, hostlen, serv, servlen, flags);
}

static inline struct hostent *ccasper_gethostbyname(void *chan, const char *name) {
    return cap_gethostbyname((cap_channel_t *)chan, name);
}

static inline struct hostent *ccasper_gethostbyname2(void *chan, const char *name, int af) {
    return cap_gethostbyname2((cap_channel_t *)chan, name, af);
}

static inline struct hostent *ccasper_gethostbyaddr(
    void *chan,
    const void *addr,
    socklen_t len,
    int af
) {
    return cap_gethostbyaddr((cap_channel_t *)chan, addr, len, af);
}

static inline int ccasper_dns_type_limit(
    void *chan,
    const char * const *types,
    size_t ntypes
) {
    return cap_dns_type_limit((cap_channel_t *)chan, types, ntypes);
}

static inline int ccasper_dns_family_limit(void *chan, const int *families, size_t nfamilies) {
    return cap_dns_family_limit((cap_channel_t *)chan, families, nfamilies);
}

/*
 * Sysctl service wrappers
 */
static inline int ccasper_sysctlbyname(
    void *chan,
    const char *name,
    void *oldp,
    size_t *oldlenp,
    const void *newp,
    size_t newlen
) {
    return cap_sysctlbyname((cap_channel_t *)chan, name, oldp, oldlenp, newp, newlen);
}

static inline int ccasper_sysctl(
    void *chan,
    const int *mib,
    u_int miblen,
    void *oldp,
    size_t *oldlenp,
    const void *newp,
    size_t newlen
) {
    return cap_sysctl((cap_channel_t *)chan, mib, miblen, oldp, oldlenp, newp, newlen);
}

static inline int ccasper_sysctlnametomib(void *chan, const char *name, int *mibp, size_t *sizep) {
    return cap_sysctlnametomib((cap_channel_t *)chan, name, mibp, sizep);
}

static inline cap_sysctl_limit_t *ccasper_sysctl_limit_init(void *chan) {
    return cap_sysctl_limit_init((cap_channel_t *)chan);
}

static inline cap_sysctl_limit_t *ccasper_sysctl_limit_name(
    cap_sysctl_limit_t *limit,
    const char *name,
    int flags
) {
    return cap_sysctl_limit_name(limit, name, flags);
}

static inline int ccasper_sysctl_limit(cap_sysctl_limit_t *limit) {
    return cap_sysctl_limit(limit);
}

/*
 * Password database service wrappers
 */
static inline struct passwd *ccasper_getpwent(void *chan) {
    return cap_getpwent((cap_channel_t *)chan);
}

static inline struct passwd *ccasper_getpwnam(void *chan, const char *name) {
    return cap_getpwnam((cap_channel_t *)chan, name);
}

static inline struct passwd *ccasper_getpwuid(void *chan, uid_t uid) {
    return cap_getpwuid((cap_channel_t *)chan, uid);
}

static inline int ccasper_getpwnam_r(
    void *chan,
    const char *name,
    struct passwd *pwd,
    char *buf,
    size_t bufsize,
    struct passwd **result
) {
    return cap_getpwnam_r((cap_channel_t *)chan, name, pwd, buf, bufsize, result);
}

static inline int ccasper_getpwuid_r(
    void *chan,
    uid_t uid,
    struct passwd *pwd,
    char *buf,
    size_t bufsize,
    struct passwd **result
) {
    return cap_getpwuid_r((cap_channel_t *)chan, uid, pwd, buf, bufsize, result);
}

static inline int ccasper_setpassent(void *chan, int stayopen) {
    return cap_setpassent((cap_channel_t *)chan, stayopen);
}

static inline void ccasper_setpwent(void *chan) {
    cap_setpwent((cap_channel_t *)chan);
}

static inline void ccasper_endpwent(void *chan) {
    cap_endpwent((cap_channel_t *)chan);
}

static inline int ccasper_pwd_limit_cmds(void *chan, const char * const *cmds, size_t ncmds) {
    return cap_pwd_limit_cmds((cap_channel_t *)chan, cmds, ncmds);
}

static inline int ccasper_pwd_limit_fields(void *chan, const char * const *fields, size_t nfields) {
    return cap_pwd_limit_fields((cap_channel_t *)chan, fields, nfields);
}

static inline int ccasper_pwd_limit_users(
    void *chan,
    const char * const *users,
    size_t nusers,
    uid_t *uids,
    size_t nuids
) {
    return cap_pwd_limit_users((cap_channel_t *)chan, users, nusers, uids, nuids);
}

/*
 * Group database service wrappers
 */
static inline struct group *ccasper_getgrent(void *chan) {
    return cap_getgrent((cap_channel_t *)chan);
}

static inline struct group *ccasper_getgrnam(void *chan, const char *name) {
    return cap_getgrnam((cap_channel_t *)chan, name);
}

static inline struct group *ccasper_getgrgid(void *chan, gid_t gid) {
    return cap_getgrgid((cap_channel_t *)chan, gid);
}

static inline int ccasper_getgrnam_r(
    void *chan,
    const char *name,
    struct group *grp,
    char *buf,
    size_t bufsize,
    struct group **result
) {
    return cap_getgrnam_r((cap_channel_t *)chan, name, grp, buf, bufsize, result);
}

static inline int ccasper_getgrgid_r(
    void *chan,
    gid_t gid,
    struct group *grp,
    char *buf,
    size_t bufsize,
    struct group **result
) {
    return cap_getgrgid_r((cap_channel_t *)chan, gid, grp, buf, bufsize, result);
}

static inline int ccasper_setgroupent(void *chan, int stayopen) {
    return cap_setgroupent((cap_channel_t *)chan, stayopen);
}

static inline void ccasper_setgrent(void *chan) {
    cap_setgrent((cap_channel_t *)chan);
}

static inline void ccasper_endgrent(void *chan) {
    cap_endgrent((cap_channel_t *)chan);
}

static inline int ccasper_grp_limit_cmds(void *chan, const char * const *cmds, size_t ncmds) {
    return cap_grp_limit_cmds((cap_channel_t *)chan, cmds, ncmds);
}

static inline int ccasper_grp_limit_fields(void *chan, const char * const *fields, size_t nfields) {
    return cap_grp_limit_fields((cap_channel_t *)chan, fields, nfields);
}

static inline int ccasper_grp_limit_groups(
    void *chan,
    const char * const *groups,
    size_t ngroups,
    gid_t *gids,
    size_t ngids
) {
    return cap_grp_limit_groups((cap_channel_t *)chan, groups, ngroups, gids, ngids);
}

/*
 * Syslog service wrappers
 */
static inline void ccasper_openlog(void *chan, const char *ident, int logopt, int facility) {
    cap_openlog((cap_channel_t *)chan, ident, logopt, facility);
}

static inline void ccasper_closelog(void *chan) {
    cap_closelog((cap_channel_t *)chan);
}

static inline int ccasper_setlogmask(void *chan, int maskpri) {
    return cap_setlogmask((cap_channel_t *)chan, maskpri);
}

static inline void ccasper_syslog(void *chan, int priority, const char *message) {
    cap_syslog((cap_channel_t *)chan, priority, "%s", message);
}

/*
 * Fileargs service wrappers
 * Note: We use void* for fileargs_t* to make Swift interop simpler
 */

/* Fileargs operation flags */
static const int CCASPER_FA_OPEN = FA_OPEN;
static const int CCASPER_FA_LSTAT = FA_LSTAT;
static const int CCASPER_FA_REALPATH = FA_REALPATH;

static inline void *ccasper_fileargs_init(
    int argc,
    char *argv[],
    int flags,
    mode_t mode,
    cap_rights_t *rightsp,
    int operations
) {
    return (void *)fileargs_init(argc, argv, flags, mode, rightsp, operations);
}

static inline void *ccasper_fileargs_cinit(
    void *casper,
    int argc,
    char *argv[],
    int flags,
    mode_t mode,
    cap_rights_t *rightsp,
    int operations
) {
    return (void *)fileargs_cinit((cap_channel_t *)casper, argc, argv, flags, mode, rightsp, operations);
}

static inline int ccasper_fileargs_open(void *fa, const char *name) {
    return fileargs_open((fileargs_t *)fa, name);
}

static inline FILE *ccasper_fileargs_fopen(void *fa, const char *name, const char *mode) {
    return fileargs_fopen((fileargs_t *)fa, name, mode);
}

static inline int ccasper_fileargs_lstat(void *fa, const char *name, struct stat *sb) {
    return fileargs_lstat((fileargs_t *)fa, name, sb);
}

static inline char *ccasper_fileargs_realpath(void *fa, const char *pathname, char *resolved_path) {
    return fileargs_realpath((fileargs_t *)fa, pathname, resolved_path);
}

static inline void ccasper_fileargs_free(void *fa) {
    fileargs_free((fileargs_t *)fa);
}

static inline void *ccasper_fileargs_wrap(void *chan, int fdflags) {
    return (void *)fileargs_wrap((cap_channel_t *)chan, fdflags);
}

static inline void *ccasper_fileargs_unwrap(void *fa, int *fdflags) {
    return (void *)fileargs_unwrap((fileargs_t *)fa, fdflags);
}

/*
 * Network service wrappers
 */

/* Network operation mode flags */
static const uint64_t CCASPER_CAPNET_ADDR2NAME = CAPNET_ADDR2NAME;
static const uint64_t CCASPER_CAPNET_NAME2ADDR = CAPNET_NAME2ADDR;
static const uint64_t CCASPER_CAPNET_DEPRECATED_ADDR2NAME = CAPNET_DEPRECATED_ADDR2NAME;
static const uint64_t CCASPER_CAPNET_DEPRECATED_NAME2ADDR = CAPNET_DEPRECATED_NAME2ADDR;
static const uint64_t CCASPER_CAPNET_CONNECT = CAPNET_CONNECT;
static const uint64_t CCASPER_CAPNET_BIND = CAPNET_BIND;
static const uint64_t CCASPER_CAPNET_CONNECTDNS = CAPNET_CONNECTDNS;

static inline int ccasper_net_bind(
    void *chan,
    int s,
    const struct sockaddr *addr,
    socklen_t addrlen
) {
    return cap_bind((cap_channel_t *)chan, s, addr, addrlen);
}

static inline int ccasper_net_connect(
    void *chan,
    int s,
    const struct sockaddr *name,
    socklen_t namelen
) {
    return cap_connect((cap_channel_t *)chan, s, name, namelen);
}

static inline int ccasper_net_getaddrinfo(
    void *chan,
    const char *hostname,
    const char *servname,
    const struct addrinfo *hints,
    struct addrinfo **res
) {
    return cap_getaddrinfo((cap_channel_t *)chan, hostname, servname, hints, res);
}

static inline int ccasper_net_getnameinfo(
    void *chan,
    const struct sockaddr *sa,
    socklen_t salen,
    char *host,
    size_t hostlen,
    char *serv,
    size_t servlen,
    int flags
) {
    return cap_getnameinfo((cap_channel_t *)chan, sa, salen, host, hostlen, serv, servlen, flags);
}

static inline void *ccasper_net_limit_init(void *chan, uint64_t mode) {
    return (void *)cap_net_limit_init((cap_channel_t *)chan, mode);
}

static inline int ccasper_net_limit(void *limit) {
    return cap_net_limit((cap_net_limit_t *)limit);
}

static inline void ccasper_net_free(void *limit) {
    cap_net_free((cap_net_limit_t *)limit);
}

static inline void *ccasper_net_limit_addr2name_family(
    void *limit,
    int *family,
    size_t size
) {
    return (void *)cap_net_limit_addr2name_family((cap_net_limit_t *)limit, family, size);
}

static inline void *ccasper_net_limit_addr2name(
    void *limit,
    const struct sockaddr *sa,
    socklen_t salen
) {
    return (void *)cap_net_limit_addr2name((cap_net_limit_t *)limit, sa, salen);
}

static inline void *ccasper_net_limit_name2addr_family(
    void *limit,
    int *family,
    size_t size
) {
    return (void *)cap_net_limit_name2addr_family((cap_net_limit_t *)limit, family, size);
}

static inline void *ccasper_net_limit_name2addr(
    void *limit,
    const char *name,
    const char *serv
) {
    return (void *)cap_net_limit_name2addr((cap_net_limit_t *)limit, name, serv);
}

static inline void *ccasper_net_limit_connect(
    void *limit,
    const struct sockaddr *sa,
    socklen_t salen
) {
    return (void *)cap_net_limit_connect((cap_net_limit_t *)limit, sa, salen);
}

static inline void *ccasper_net_limit_bind(
    void *limit,
    const struct sockaddr *sa,
    socklen_t salen
) {
    return (void *)cap_net_limit_bind((cap_net_limit_t *)limit, sa, salen);
}

/* Deprecated network functions */
static inline struct hostent *ccasper_net_gethostbyname(void *chan, const char *name) {
    return cap_gethostbyname((cap_channel_t *)chan, name);
}

static inline struct hostent *ccasper_net_gethostbyname2(void *chan, const char *name, int af) {
    return cap_gethostbyname2((cap_channel_t *)chan, name, af);
}

static inline struct hostent *ccasper_net_gethostbyaddr(
    void *chan,
    const void *addr,
    socklen_t len,
    int af
) {
    return cap_gethostbyaddr((cap_channel_t *)chan, addr, len, af);
}

/*
 * Netdb service wrappers
 */
static inline struct protoent *ccasper_netdb_getprotobyname(void *chan, const char *name) {
    return cap_getprotobyname((cap_channel_t *)chan, name);
}

#endif /* CCASPER_H */
