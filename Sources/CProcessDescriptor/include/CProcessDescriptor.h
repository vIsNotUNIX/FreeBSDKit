/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */
#pragma once

#include <sys/param.h>
#include <sys/procdesc.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <unistd.h>
#include <errno.h>
#include <stdbool.h>

/**
 * Wait status decoding helpers.
 *
 * FreeBSD's wait(2) status macros cannot be imported directly into Swift,
 * so we provide inline C wrappers for proper status decoding.
 */

static inline bool cwait_wifexited(int status) {
    return WIFEXITED(status);
}

static inline int cwait_wexitstatus(int status) {
    return WEXITSTATUS(status);
}

static inline bool cwait_wifsignaled(int status) {
    return WIFSIGNALED(status);
}

static inline int cwait_wtermsig(int status) {
    return WTERMSIG(status);
}

static inline bool cwait_wcoredump(int status) {
    return WCOREDUMP(status);
}

static inline bool cwait_wifstopped(int status) {
    return WIFSTOPPED(status);
}

static inline int cwait_wstopsig(int status) {
    return WSTOPSIG(status);
}