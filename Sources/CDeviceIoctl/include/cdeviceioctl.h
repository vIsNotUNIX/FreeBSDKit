/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/filio.h>
#include <sys/disk.h>
#include <sys/conf.h>

/*
 * Device type flags from sys/conf.h
 * These describe characteristics of the device.
 */
static const int CDEV_D_DISK = D_DISK;
static const int CDEV_D_TTY = D_TTY;
static const int CDEV_D_MEM = D_MEM;

/*
 * Common file/device ioctls from sys/filio.h
 * Swift cannot import the _IOR/_IOW macros, so we provide constants.
 */
static const unsigned long CDEV_FIONREAD = FIONREAD;
static const unsigned long CDEV_FIONWRITE = FIONWRITE;
static const unsigned long CDEV_FIONSPACE = FIONSPACE;
static const unsigned long CDEV_FIONBIO = FIONBIO;
static const unsigned long CDEV_FIOASYNC = FIOASYNC;
static const unsigned long CDEV_FIODTYPE = FIODTYPE;
static const unsigned long CDEV_FIODGNAME = FIODGNAME;
static const unsigned long CDEV_FIOCLEX = FIOCLEX;
static const unsigned long CDEV_FIONCLEX = FIONCLEX;

/*
 * Disk ioctls from sys/disk.h
 */
static const unsigned long CDEV_DIOCGSECTORSIZE = DIOCGSECTORSIZE;
static const unsigned long CDEV_DIOCGMEDIASIZE = DIOCGMEDIASIZE;
static const unsigned long CDEV_DIOCGFLUSH = DIOCGFLUSH;
static const unsigned long CDEV_DIOCGIDENT = DIOCGIDENT;
static const unsigned long CDEV_DIOCGSTRIPESIZE = DIOCGSTRIPESIZE;
static const unsigned long CDEV_DIOCGSTRIPEOFFSET = DIOCGSTRIPEOFFSET;
static const unsigned long CDEV_DIOCGFWSECTORS = DIOCGFWSECTORS;
static const unsigned long CDEV_DIOCGFWHEADS = DIOCGFWHEADS;

/*
 * Disk identity size
 */
static const int CDEV_DISK_IDENT_SIZE = DISK_IDENT_SIZE;

/*
 * Wrapper functions for ioctl calls.
 * Swift cannot call variadic C functions, so we provide typed wrappers.
 */

/// ioctl with no argument
static inline int
cdev_ioctl_void(int fd, unsigned long request) {
    return ioctl(fd, request);
}

/// ioctl with pointer argument
static inline int
cdev_ioctl_ptr(int fd, unsigned long request, void *arg) {
    return ioctl(fd, request, arg);
}
