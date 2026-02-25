/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CRCTL_H
#define CRCTL_H

#include <sys/types.h>
#include <sys/rctl.h>
#include <errno.h>

/*
 * Wrapper functions for rctl syscalls.
 * The rctl API is string-based - rules are specified as:
 *   subject:subject-id:resource:action=amount[/per]
 * e.g., "user:1000:memoryuse:deny=536870912"
 */

static inline int crctl_get_racct(const char *filter, size_t filterlen,
    char *outbuf, size_t outbuflen) {
    return rctl_get_racct(filter, filterlen, outbuf, outbuflen);
}

static inline int crctl_get_rules(const char *filter, size_t filterlen,
    char *outbuf, size_t outbuflen) {
    return rctl_get_rules(filter, filterlen, outbuf, outbuflen);
}

static inline int crctl_get_limits(const char *filter, size_t filterlen,
    char *outbuf, size_t outbuflen) {
    return rctl_get_limits(filter, filterlen, outbuf, outbuflen);
}

static inline int crctl_add_rule(const char *rule, size_t rulelen,
    char *outbuf, size_t outbuflen) {
    return rctl_add_rule(rule, rulelen, outbuf, outbuflen);
}

static inline int crctl_remove_rule(const char *rule, size_t rulelen,
    char *outbuf, size_t outbuflen) {
    return rctl_remove_rule(rule, rulelen, outbuf, outbuflen);
}

#endif /* CRCTL_H */
