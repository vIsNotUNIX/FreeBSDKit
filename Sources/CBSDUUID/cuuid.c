/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "include/cuuid.h"
#include <uuid.h>
#include <string.h>

/*
 * Convert between FreeBSD uuid_t and our byte representation.
 * FreeBSD uuid_t is in host byte order, we store in RFC 4122 byte order.
 */
static void uuid_to_bytes(const struct uuid *u, cuuid_bytes_t *b) {
    /* time_low: big-endian */
    b->bytes[0] = (u->time_low >> 24) & 0xFF;
    b->bytes[1] = (u->time_low >> 16) & 0xFF;
    b->bytes[2] = (u->time_low >> 8) & 0xFF;
    b->bytes[3] = u->time_low & 0xFF;
    /* time_mid: big-endian */
    b->bytes[4] = (u->time_mid >> 8) & 0xFF;
    b->bytes[5] = u->time_mid & 0xFF;
    /* time_hi_and_version: big-endian */
    b->bytes[6] = (u->time_hi_and_version >> 8) & 0xFF;
    b->bytes[7] = u->time_hi_and_version & 0xFF;
    /* clock_seq */
    b->bytes[8] = u->clock_seq_hi_and_reserved;
    b->bytes[9] = u->clock_seq_low;
    /* node */
    memcpy(&b->bytes[10], u->node, 6);
}

static void bytes_to_uuid(const cuuid_bytes_t *b, struct uuid *u) {
    u->time_low = ((uint32_t)b->bytes[0] << 24) |
                  ((uint32_t)b->bytes[1] << 16) |
                  ((uint32_t)b->bytes[2] << 8) |
                  (uint32_t)b->bytes[3];
    u->time_mid = ((uint16_t)b->bytes[4] << 8) | (uint16_t)b->bytes[5];
    u->time_hi_and_version = ((uint16_t)b->bytes[6] << 8) | (uint16_t)b->bytes[7];
    u->clock_seq_hi_and_reserved = b->bytes[8];
    u->clock_seq_low = b->bytes[9];
    memcpy(u->node, &b->bytes[10], 6);
}

int cuuid_generate(cuuid_bytes_t *uuids, int count) {
    if (count <= 0 || count > 2048 || uuids == NULL) {
        return -1;
    }

    /* Allocate temporary array for system UUIDs */
    struct uuid *sys_uuids = malloc(count * sizeof(struct uuid));
    if (sys_uuids == NULL) {
        return -1;
    }

    int result = uuidgen(sys_uuids, count);
    if (result == 0) {
        for (int i = 0; i < count; i++) {
            uuid_to_bytes(&sys_uuids[i], &uuids[i]);
        }
    }

    free(sys_uuids);
    return result;
}

int cuuid_from_string(const char *str, cuuid_bytes_t *uuid) {
    if (str == NULL || uuid == NULL) {
        return -1;
    }

    struct uuid u;
    uint32_t status;
    uuid_from_string(str, &u, &status);

    if (status != 0) {
        return -1;
    }

    uuid_to_bytes(&u, uuid);
    return 0;
}

char *cuuid_to_string(const cuuid_bytes_t *uuid) {
    if (uuid == NULL) {
        return NULL;
    }

    struct uuid u;
    bytes_to_uuid(uuid, &u);

    char *str = NULL;
    uint32_t status;
    uuid_to_string(&u, &str, &status);

    if (status != 0) {
        return NULL;
    }

    return str;
}

int cuuid_is_nil(const cuuid_bytes_t *uuid) {
    if (uuid == NULL) {
        return 0;
    }

    struct uuid u;
    bytes_to_uuid(uuid, &u);

    uint32_t status;
    return uuid_is_nil(&u, &status);
}

int cuuid_compare(const cuuid_bytes_t *a, const cuuid_bytes_t *b) {
    if (a == NULL || b == NULL) {
        return 0;
    }

    struct uuid ua, ub;
    bytes_to_uuid(a, &ua);
    bytes_to_uuid(b, &ub);

    uint32_t status;
    return uuid_compare(&ua, &ub, &status);
}
