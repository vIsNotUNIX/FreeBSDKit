/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Kernel-safe parser for MacLabel extended attribute format.
 *
 * This library parses the key=value\n format used by the MacLabel tool.
 * It has no libc dependencies and is safe for use in FreeBSD kernel modules.
 *
 * Format:
 *   key1=value1\n
 *   key2=value2\n
 *   key3=value3\n
 *
 * Keys are sorted alphabetically. Keys cannot contain '=' or '\n'.
 * Values can contain '=' but not '\n'.
 */

#ifndef _MACLABEL_PARSER_H_
#define _MACLABEL_PARSER_H_

#ifdef _KERNEL
#include <sys/types.h>
#else
#include <stddef.h>
#include <stdbool.h>
#endif

/*
 * Parser context for iterating over label entries.
 * Initialize with maclabel_parser_init(), then call maclabel_parser_next()
 * repeatedly until it returns false.
 */
struct maclabel_parser {
    const char *data;       /* Current position in label data */
    const char *end;        /* End of label data */
};

/*
 * A single key-value entry from a label.
 * Pointers reference the original data buffer (not copies).
 * Strings are NOT null-terminated - use the length fields.
 */
struct maclabel_entry {
    const char *key;        /* Pointer to key (not null-terminated) */
    size_t      key_len;    /* Length of key */
    const char *value;      /* Pointer to value (not null-terminated) */
    size_t      value_len;  /* Length of value */
};

/*
 * Initialize a parser context.
 *
 * @param parser    Parser context to initialize
 * @param data      Label data buffer (from extended attribute)
 * @param len       Length of data in bytes
 */
static inline void
maclabel_parser_init(struct maclabel_parser *parser, const char *data, size_t len)
{
    parser->data = data;
    parser->end = data + len;
}

/*
 * Parse the next key-value entry.
 *
 * @param parser    Parser context (modified on each call)
 * @param entry     Output: populated with next entry if found
 * @return          true if entry was found, false if no more entries
 *
 * Usage:
 *   struct maclabel_parser parser;
 *   struct maclabel_entry entry;
 *
 *   maclabel_parser_init(&parser, data, len);
 *   while (maclabel_parser_next(&parser, &entry)) {
 *       // Process entry.key (length: entry.key_len)
 *       // Process entry.value (length: entry.value_len)
 *   }
 */
bool maclabel_parser_next(struct maclabel_parser *parser,
                          struct maclabel_entry *entry);

/*
 * Find a specific key in the label data.
 *
 * Since keys are sorted, this uses binary search for O(log n) lookup.
 * For small labels, linear search may be faster - use maclabel_find_linear().
 *
 * @param data      Label data buffer
 * @param len       Length of data in bytes
 * @param key       Key to search for (null-terminated)
 * @param value     Output: pointer to value (not null-terminated)
 * @param value_len Output: length of value
 * @return          true if key found, false otherwise
 */
bool maclabel_find(const char *data, size_t len,
                   const char *key,
                   const char **value, size_t *value_len);

/*
 * Find a specific key using linear search.
 *
 * Simpler than binary search, may be faster for labels with <10 entries.
 *
 * @param data      Label data buffer
 * @param len       Length of data in bytes
 * @param key       Key to search for (null-terminated)
 * @param value     Output: pointer to value (not null-terminated)
 * @param value_len Output: length of value
 * @return          true if key found, false otherwise
 */
bool maclabel_find_linear(const char *data, size_t len,
                          const char *key,
                          const char **value, size_t *value_len);

/*
 * Compare a non-null-terminated string with a null-terminated string.
 *
 * Useful for comparing entry values against known strings.
 *
 * @param s1        Non-null-terminated string
 * @param s1_len    Length of s1
 * @param s2        Null-terminated string
 * @return          true if strings are equal
 */
static inline bool
maclabel_streq(const char *s1, size_t s1_len, const char *s2)
{
    size_t i;
    for (i = 0; i < s1_len && s2[i] != '\0'; i++) {
        if (s1[i] != s2[i])
            return false;
    }
    return (i == s1_len && s2[i] == '\0');
}

/*
 * Count the number of entries in a label.
 *
 * @param data      Label data buffer
 * @param len       Length of data in bytes
 * @return          Number of key-value entries
 */
size_t maclabel_count(const char *data, size_t len);

/*
 * Validate label format.
 *
 * Checks that:
 * - All lines have format key=value
 * - No empty keys
 * - No embedded nulls
 *
 * @param data      Label data buffer
 * @param len       Length of data in bytes
 * @return          true if valid, false if malformed
 */
bool maclabel_validate(const char *data, size_t len);

#endif /* _MACLABEL_PARSER_H_ */
