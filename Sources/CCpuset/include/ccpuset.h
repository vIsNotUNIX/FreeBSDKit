/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CCPUSET_H
#define CCPUSET_H

#include <sys/types.h>
#include <sys/domainset.h>
#include <sys/cpuset.h>
#include <strings.h>
#include <errno.h>

/*
 * Re-export cpuset constants for Swift access.
 */

/* CPU levels */
static const int CCPUSET_LEVEL_ROOT = CPU_LEVEL_ROOT;
static const int CCPUSET_LEVEL_CPUSET = CPU_LEVEL_CPUSET;
static const int CCPUSET_LEVEL_WHICH = CPU_LEVEL_WHICH;

/* CPU which types */
static const int CCPUSET_WHICH_TID = CPU_WHICH_TID;
static const int CCPUSET_WHICH_PID = CPU_WHICH_PID;
static const int CCPUSET_WHICH_CPUSET = CPU_WHICH_CPUSET;
static const int CCPUSET_WHICH_IRQ = CPU_WHICH_IRQ;
static const int CCPUSET_WHICH_JAIL = CPU_WHICH_JAIL;
static const int CCPUSET_WHICH_DOMAIN = CPU_WHICH_DOMAIN;
static const int CCPUSET_WHICH_INTRHANDLER = CPU_WHICH_INTRHANDLER;
static const int CCPUSET_WHICH_ITHREAD = CPU_WHICH_ITHREAD;
static const int CCPUSET_WHICH_TIDPID = CPU_WHICH_TIDPID;

/* Reserved cpuset IDs */
static const cpusetid_t CCPUSET_INVALID = CPUSET_INVALID;
static const cpusetid_t CCPUSET_DEFAULT = CPUSET_DEFAULT;

/* Domain policies */
static const int CCPUSET_POLICY_ROUNDROBIN = DOMAINSET_POLICY_ROUNDROBIN;
static const int CCPUSET_POLICY_FIRSTTOUCH = DOMAINSET_POLICY_FIRSTTOUCH;
static const int CCPUSET_POLICY_PREFER = DOMAINSET_POLICY_PREFER;
static const int CCPUSET_POLICY_INTERLEAVE = DOMAINSET_POLICY_INTERLEAVE;

/* CPU_SETSIZE for Swift */
static const int CCPUSET_SETSIZE = CPU_SETSIZE;

/*
 * Wrapper functions for cpuset_t manipulation macros.
 */

static inline void ccpuset_zero(cpuset_t *set) {
    CPU_ZERO(set);
}

static inline void ccpuset_fill(cpuset_t *set) {
    CPU_FILL(set);
}

static inline void ccpuset_set(int cpu, cpuset_t *set) {
    CPU_SET(cpu, set);
}

static inline void ccpuset_clr(int cpu, cpuset_t *set) {
    CPU_CLR(cpu, set);
}

static inline int ccpuset_isset(int cpu, const cpuset_t *set) {
    return CPU_ISSET(cpu, set);
}

static inline int ccpuset_count(const cpuset_t *set) {
    return CPU_COUNT(set);
}

static inline int ccpuset_empty(const cpuset_t *set) {
    return CPU_EMPTY(set);
}

static inline int ccpuset_isfullset(const cpuset_t *set) {
    return CPU_ISFULLSET(set);
}

static inline void ccpuset_copy(const cpuset_t *from, cpuset_t *to) {
    CPU_COPY(from, to);
}

static inline int ccpuset_equal(const cpuset_t *a, const cpuset_t *b) {
    return CPU_EQUAL(a, b);
}

static inline void ccpuset_or(cpuset_t *dst, const cpuset_t *a, const cpuset_t *b) {
    CPU_OR(dst, a, b);
}

static inline void ccpuset_and(cpuset_t *dst, const cpuset_t *a, const cpuset_t *b) {
    CPU_AND(dst, a, b);
}

static inline void ccpuset_andnot(cpuset_t *dst, const cpuset_t *a, const cpuset_t *b) {
    CPU_ANDNOT(dst, a, b);
}

static inline int ccpuset_ffs(const cpuset_t *set) {
    return CPU_FFS(set);
}

static inline int ccpuset_fls(const cpuset_t *set) {
    return CPU_FLS(set);
}

/*
 * Wrapper functions for domainset_t manipulation macros.
 */

static inline void cdomainset_zero(domainset_t *set) {
    DOMAINSET_ZERO(set);
}

static inline void cdomainset_fill(domainset_t *set) {
    DOMAINSET_FILL(set);
}

static inline void cdomainset_set(int domain, domainset_t *set) {
    DOMAINSET_SET(domain, set);
}

static inline void cdomainset_clr(int domain, domainset_t *set) {
    DOMAINSET_CLR(domain, set);
}

static inline int cdomainset_isset(int domain, const domainset_t *set) {
    return DOMAINSET_ISSET(domain, set);
}

static inline int cdomainset_count(const domainset_t *set) {
    return DOMAINSET_COUNT(set);
}

static inline int cdomainset_empty(const domainset_t *set) {
    return DOMAINSET_EMPTY(set);
}

/*
 * Syscall wrappers.
 */

static inline int ccpuset_create(cpusetid_t *setid) {
    return cpuset(setid);
}

static inline int ccpuset_getid(cpulevel_t level, cpuwhich_t which,
    id_t id, cpusetid_t *setid) {
    return cpuset_getid(level, which, id, setid);
}

static inline int ccpuset_setid(cpuwhich_t which, id_t id, cpusetid_t setid) {
    return cpuset_setid(which, id, setid);
}

static inline int ccpuset_getaffinity(cpulevel_t level, cpuwhich_t which,
    id_t id, size_t setsize, cpuset_t *mask) {
    return cpuset_getaffinity(level, which, id, setsize, mask);
}

static inline int ccpuset_setaffinity(cpulevel_t level, cpuwhich_t which,
    id_t id, size_t setsize, const cpuset_t *mask) {
    return cpuset_setaffinity(level, which, id, setsize, mask);
}

static inline int ccpuset_getdomain(cpulevel_t level, cpuwhich_t which,
    id_t id, size_t setsize, domainset_t *mask, int *policy) {
    return cpuset_getdomain(level, which, id, setsize, mask, policy);
}

static inline int ccpuset_setdomain(cpulevel_t level, cpuwhich_t which,
    id_t id, size_t setsize, const domainset_t *mask, int policy) {
    return cpuset_setdomain(level, which, id, setsize, mask, policy);
}

#endif /* CCPUSET_H */
