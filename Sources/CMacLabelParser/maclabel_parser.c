/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Kernel-safe parser for MacLabel extended attribute format.
 */

#include "include/maclabel_parser.h"

/*
 * Helper: find character in bounded string.
 * Returns pointer to character or NULL if not found.
 */
static const char *
find_char(const char *s, const char *end, char c)
{
    while (s < end) {
        if (*s == c)
            return s;
        s++;
    }
    return NULL;
}

/*
 * Helper: compare non-null-terminated string with null-terminated string.
 * Returns <0, 0, >0 like strcmp.
 */
static int
compare_key(const char *key, size_t key_len, const char *target)
{
    size_t i;

    for (i = 0; i < key_len && target[i] != '\0'; i++) {
        if ((unsigned char)key[i] < (unsigned char)target[i])
            return -1;
        if ((unsigned char)key[i] > (unsigned char)target[i])
            return 1;
    }

    /* If we exhausted key, check if target is longer */
    if (i == key_len) {
        if (target[i] == '\0')
            return 0;   /* Equal */
        return -1;      /* Key is prefix of target */
    }

    /* We exhausted target first, key is longer */
    return 1;
}

/*
 * Helper: calculate string length (kernel doesn't have strlen).
 */
static size_t
str_len(const char *s)
{
    size_t len = 0;
    while (s[len] != '\0')
        len++;
    return len;
}

bool
maclabel_parser_next(struct maclabel_parser *parser, struct maclabel_entry *entry)
{
    const char *line_start;
    const char *line_end;
    const char *eq;

    /* Skip any leading empty lines */
    while (parser->data < parser->end && *parser->data == '\n')
        parser->data++;

    /* Check if we're at the end */
    if (parser->data >= parser->end)
        return false;

    line_start = parser->data;

    /* Find end of line */
    line_end = find_char(line_start, parser->end, '\n');
    if (line_end == NULL) {
        /* Last line without trailing newline */
        line_end = parser->end;
        parser->data = parser->end;
    } else {
        /* Move past the newline for next iteration */
        parser->data = line_end + 1;
    }

    /* Empty line */
    if (line_start == line_end)
        return maclabel_parser_next(parser, entry);

    /* Find the '=' separator */
    eq = find_char(line_start, line_end, '=');
    if (eq == NULL) {
        /* Malformed line - skip it */
        return maclabel_parser_next(parser, entry);
    }

    /* Populate entry */
    entry->key = line_start;
    entry->key_len = eq - line_start;
    entry->value = eq + 1;
    entry->value_len = line_end - (eq + 1);

    return true;
}

bool
maclabel_find_linear(const char *data, size_t len,
                     const char *key,
                     const char **value, size_t *value_len)
{
    struct maclabel_parser parser;
    struct maclabel_entry entry;
    size_t key_len = str_len(key);

    maclabel_parser_init(&parser, data, len);

    while (maclabel_parser_next(&parser, &entry)) {
        if (entry.key_len == key_len) {
            /* Compare key */
            bool match = true;
            for (size_t i = 0; i < key_len; i++) {
                if (entry.key[i] != key[i]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                *value = entry.value;
                *value_len = entry.value_len;
                return true;
            }
        }
    }

    return false;
}

bool
maclabel_find(const char *data, size_t len,
              const char *key,
              const char **value, size_t *value_len)
{
    /*
     * Binary search over sorted keys.
     *
     * First, we need to build an index of line starts.
     * Since we can't allocate, we count lines and use a fixed-size
     * stack array. For labels with more entries, fall back to linear.
     */
    #define MAX_ENTRIES 64
    const char *lines[MAX_ENTRIES];
    size_t line_count = 0;

    const char *p = data;
    const char *end = data + len;

    /* Build index of line starts */
    while (p < end && line_count < MAX_ENTRIES) {
        /* Skip empty lines */
        while (p < end && *p == '\n')
            p++;
        if (p >= end)
            break;

        lines[line_count++] = p;

        /* Find end of line */
        while (p < end && *p != '\n')
            p++;
        if (p < end)
            p++; /* Skip newline */
    }

    /* If too many entries, fall back to linear search */
    if (line_count >= MAX_ENTRIES)
        return maclabel_find_linear(data, len, key, value, value_len);

    /* Binary search */
    size_t lo = 0;
    size_t hi = line_count;

    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        const char *line = lines[mid];

        /* Find '=' in this line */
        const char *line_end = find_char(line, end, '\n');
        if (line_end == NULL)
            line_end = end;

        const char *eq = find_char(line, line_end, '=');
        if (eq == NULL) {
            /* Malformed line, skip */
            lo = mid + 1;
            continue;
        }

        size_t entry_key_len = eq - line;
        int cmp = compare_key(line, entry_key_len, key);

        if (cmp == 0) {
            /* Found it */
            *value = eq + 1;
            *value_len = line_end - (eq + 1);
            return true;
        } else if (cmp < 0) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }

    return false;
    #undef MAX_ENTRIES
}

size_t
maclabel_count(const char *data, size_t len)
{
    struct maclabel_parser parser;
    struct maclabel_entry entry;
    size_t count = 0;

    maclabel_parser_init(&parser, data, len);
    while (maclabel_parser_next(&parser, &entry))
        count++;

    return count;
}

bool
maclabel_validate(const char *data, size_t len)
{
    const char *p = data;
    const char *end = data + len;

    while (p < end) {
        /* Skip empty lines */
        if (*p == '\n') {
            p++;
            continue;
        }

        const char *line_start = p;

        /* Find end of line */
        const char *line_end = find_char(p, end, '\n');
        if (line_end == NULL)
            line_end = end;

        /* Check for embedded nulls */
        for (const char *c = line_start; c < line_end; c++) {
            if (*c == '\0')
                return false;
        }

        /* Find '=' separator */
        const char *eq = find_char(line_start, line_end, '=');
        if (eq == NULL)
            return false;  /* Missing '=' */

        /* Check key is not empty */
        if (eq == line_start)
            return false;  /* Empty key */

        /* Check key doesn't contain '=' (first '=' is the separator) */
        /* This is inherently satisfied by how we find eq */

        /* Move to next line */
        p = (line_end < end) ? line_end + 1 : end;
    }

    return true;
}
