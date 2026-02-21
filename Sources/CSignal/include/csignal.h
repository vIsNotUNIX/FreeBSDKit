/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CSIGNAL_H
#define CSIGNAL_H

#include <signal.h>
#include <string.h>

/**
 * Helper to set sigaction to SIG_IGN without dealing with Swift's union handling.
 *
 * Properly initializes all fields:
 * - memset ensures no uninitialized padding bytes
 * - sigemptyset is still needed (sigset_t internals are opaque)
 * - sa_flags set to 0 (no special behavior)
 */
static inline void csignal_set_ignore(struct sigaction *act) {
    // Zero the entire struct first to ensure no uninitialized fields
    memset(act, 0, sizeof(*act));

    // Set handler to SIG_IGN
    act->sa_handler = SIG_IGN;

    // Initialize signal mask (portable even after memset)
    sigemptyset(&act->sa_mask);

    // No special flags
    act->sa_flags = 0;
}

/**
 * Wrapper for sigaction(2) to avoid Swift import conflicts with struct sigaction.
 *
 * FreeBSD's Swift import can confuse the sigaction struct constructor with the
 * sigaction() function. This wrapper provides unambiguous access to the C function.
 */
static inline int csignal_action(int sig, const struct sigaction *act, struct sigaction *oldact) {
    return sigaction(sig, act, oldact);
}

#endif /* CSIGNAL_H */
