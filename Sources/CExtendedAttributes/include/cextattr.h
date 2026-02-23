/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <sys/types.h>
#include <sys/extattr.h>

/**
 * @file cextattr.h
 * @brief Bridge to FreeBSD extended attribute constants.
 *
 * This header re-exports FreeBSD extended attribute namespace constants
 * for use in Swift. The values are defined by the system headers and will
 * automatically match the running FreeBSD version.
 */

/**
 * @brief Extended attribute namespace constants.
 *
 * These constants correspond to FreeBSD's EXTATTR_NAMESPACE_* macros
 * from sys/extattr.h:
 * - EXTATTR_NAMESPACE_USER: User namespace (accessible by file owner)
 * - EXTATTR_NAMESPACE_SYSTEM: System namespace (requires privileges, used for MAC labels)
 */

// Re-export system constants
static const int CEXTATTR_NAMESPACE_USER = EXTATTR_NAMESPACE_USER;
static const int CEXTATTR_NAMESPACE_SYSTEM = EXTATTR_NAMESPACE_SYSTEM;
