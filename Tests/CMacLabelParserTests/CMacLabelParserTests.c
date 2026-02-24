/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Tests for CMacLabelParser.
 * Can be compiled standalone: cc -o test_parser test_parser.c ../Sources/CMacLabelParser/maclabel_parser.c -I../Sources/CMacLabelParser/include
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "maclabel_parser.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) \
    static void test_##name(int *passed); \
    static void run_test_##name(void) { \
        int passed = 1; \
        tests_run++; \
        printf("  %s... ", #name); \
        test_##name(&passed); \
        if (passed) { \
            tests_passed++; \
            printf("OK\n"); \
        } \
    } \
    static void test_##name(int *_test_passed)

#define ASSERT(cond) do { \
    if (!(cond)) { \
        printf("FAILED\n    Assertion failed: %s\n    at %s:%d\n", \
               #cond, __FILE__, __LINE__); \
        *_test_passed = 0; \
        return; \
    } \
} while(0)

/* Test data */
static const char *simple_label = "network=allow\ntrust=system\ntype=daemon\n";
static const char *no_trailing_newline = "key=value";
static const char *empty_value = "key=\n";
static const char *value_with_equals = "url=http://example.com?foo=bar\n";
static const char *empty_label = "";
static const char *only_newlines = "\n\n\n";

/* Tests */

TEST(parser_simple) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;
    int count = 0;

    maclabel_parser_init(&parser, simple_label, strlen(simple_label));

    while (maclabel_parser_next(&parser, &entry)) {
        count++;
        if (count == 1) {
            ASSERT(entry.key_len == 7);
            ASSERT(memcmp(entry.key, "network", 7) == 0);
            ASSERT(entry.value_len == 5);
            ASSERT(memcmp(entry.value, "allow", 5) == 0);
        }
    }

    ASSERT(count == 3);
}

TEST(parser_no_trailing_newline) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, no_trailing_newline, strlen(no_trailing_newline));

    ASSERT(maclabel_parser_next(&parser, &entry));
    ASSERT(entry.key_len == 3);
    ASSERT(memcmp(entry.key, "key", 3) == 0);
    ASSERT(entry.value_len == 5);
    ASSERT(memcmp(entry.value, "value", 5) == 0);

    ASSERT(!maclabel_parser_next(&parser, &entry));
}

TEST(parser_empty_value) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, empty_value, strlen(empty_value));

    ASSERT(maclabel_parser_next(&parser, &entry));
    ASSERT(entry.key_len == 3);
    ASSERT(entry.value_len == 0);

    ASSERT(!maclabel_parser_next(&parser, &entry));
}

TEST(parser_value_with_equals) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, value_with_equals, strlen(value_with_equals));

    ASSERT(maclabel_parser_next(&parser, &entry));
    ASSERT(entry.key_len == 3);
    ASSERT(memcmp(entry.key, "url", 3) == 0);
    /* Value should include the second '=' */
    ASSERT(entry.value_len == 26);
    ASSERT(memcmp(entry.value, "http://example.com?foo=bar", 26) == 0);

    ASSERT(!maclabel_parser_next(&parser, &entry));
}

TEST(parser_empty_label) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, empty_label, 0);
    ASSERT(!maclabel_parser_next(&parser, &entry));
}

TEST(parser_only_newlines) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, only_newlines, strlen(only_newlines));
    ASSERT(!maclabel_parser_next(&parser, &entry));
}

TEST(find_linear_exists) {
    const char *value;
    size_t value_len;

    ASSERT(maclabel_find_linear(simple_label, strlen(simple_label),
                                "trust", &value, &value_len));
    ASSERT(value_len == 6);
    ASSERT(memcmp(value, "system", 6) == 0);
}

TEST(find_linear_not_exists) {
    const char *value;
    size_t value_len;

    ASSERT(!maclabel_find_linear(simple_label, strlen(simple_label),
                                 "nonexistent", &value, &value_len));
}

TEST(find_binary_exists) {
    const char *value;
    size_t value_len;

    ASSERT(maclabel_find(simple_label, strlen(simple_label),
                         "type", &value, &value_len));
    ASSERT(value_len == 6);
    ASSERT(memcmp(value, "daemon", 6) == 0);
}

TEST(find_binary_first_key) {
    const char *value;
    size_t value_len;

    ASSERT(maclabel_find(simple_label, strlen(simple_label),
                         "network", &value, &value_len));
    ASSERT(maclabel_streq(value, value_len, "allow"));
}

TEST(find_binary_last_key) {
    const char *value;
    size_t value_len;

    ASSERT(maclabel_find(simple_label, strlen(simple_label),
                         "type", &value, &value_len));
    ASSERT(maclabel_streq(value, value_len, "daemon"));
}

TEST(find_binary_not_exists) {
    const char *value;
    size_t value_len;

    ASSERT(!maclabel_find(simple_label, strlen(simple_label),
                          "zzz", &value, &value_len));
    ASSERT(!maclabel_find(simple_label, strlen(simple_label),
                          "aaa", &value, &value_len));
}

TEST(streq_match) {
    ASSERT(maclabel_streq("allow", 5, "allow"));
    ASSERT(maclabel_streq("", 0, ""));
}

TEST(streq_no_match) {
    ASSERT(!maclabel_streq("allow", 5, "deny"));
    ASSERT(!maclabel_streq("allow", 5, "allowx"));
    ASSERT(!maclabel_streq("allowx", 6, "allow"));
    ASSERT(!maclabel_streq("allow", 4, "allow")); /* Truncated */
}

TEST(count_entries) {
    ASSERT(maclabel_count(simple_label, strlen(simple_label)) == 3);
    ASSERT(maclabel_count(empty_label, 0) == 0);
    ASSERT(maclabel_count(only_newlines, strlen(only_newlines)) == 0);
    ASSERT(maclabel_count(no_trailing_newline, strlen(no_trailing_newline)) == 1);
}

TEST(validate_good) {
    ASSERT(maclabel_validate(simple_label, strlen(simple_label)));
    ASSERT(maclabel_validate(no_trailing_newline, strlen(no_trailing_newline)));
    ASSERT(maclabel_validate(empty_value, strlen(empty_value)));
    ASSERT(maclabel_validate(value_with_equals, strlen(value_with_equals)));
    ASSERT(maclabel_validate(empty_label, 0));
    ASSERT(maclabel_validate(only_newlines, strlen(only_newlines)));
}

TEST(validate_missing_equals) {
    const char *bad = "noequals\n";
    ASSERT(!maclabel_validate(bad, strlen(bad)));
}

TEST(validate_empty_key) {
    const char *bad = "=value\n";
    ASSERT(!maclabel_validate(bad, strlen(bad)));
}

TEST(validate_embedded_null) {
    const char bad[] = "key=val\0ue\n";
    ASSERT(!maclabel_validate(bad, sizeof(bad) - 1));
}

/* Main */

int main(void) {
    printf("CMacLabelParser Tests\n");
    printf("=====================\n\n");

    printf("Parser tests:\n");
    run_test_parser_simple();
    run_test_parser_no_trailing_newline();
    run_test_parser_empty_value();
    run_test_parser_value_with_equals();
    run_test_parser_empty_label();
    run_test_parser_only_newlines();

    printf("\nFind tests:\n");
    run_test_find_linear_exists();
    run_test_find_linear_not_exists();
    run_test_find_binary_exists();
    run_test_find_binary_first_key();
    run_test_find_binary_last_key();
    run_test_find_binary_not_exists();

    printf("\nString comparison tests:\n");
    run_test_streq_match();
    run_test_streq_no_match();

    printf("\nUtility tests:\n");
    run_test_count_entries();
    run_test_validate_good();
    run_test_validate_missing_equals();
    run_test_validate_empty_key();
    run_test_validate_embedded_null();

    printf("\n=====================\n");
    printf("Results: %d/%d tests passed\n", tests_passed, tests_run);

    return (tests_passed == tests_run) ? 0 : 1;
}
