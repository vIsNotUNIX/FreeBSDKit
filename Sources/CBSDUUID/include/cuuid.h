/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CUUID_H
#define CUUID_H

#include <stdint.h>
#include <stdlib.h>

/* Raw 16-byte UUID representation for Swift interop */
typedef struct {
    uint8_t bytes[16];
} cuuid_bytes_t;

/* Generate one or more UUIDs */
int cuuid_generate(cuuid_bytes_t *uuids, int count);

/* Parse UUID from string (hyphenated or compact) */
int cuuid_from_string(const char *str, cuuid_bytes_t *uuid);

/* Convert UUID to string (returns malloc'd string, caller must free) */
char *cuuid_to_string(const cuuid_bytes_t *uuid);

/* Check if UUID is nil */
int cuuid_is_nil(const cuuid_bytes_t *uuid);

/* Compare two UUIDs (returns <0, 0, or >0) */
int cuuid_compare(const cuuid_bytes_t *a, const cuuid_bytes_t *b);

#endif /* CUUID_H */
