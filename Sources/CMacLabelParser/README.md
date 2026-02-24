# CMacLabelParser

Kernel-safe C library for parsing MacLabel extended attribute format.

## Features

- **No libc dependencies** - Safe for FreeBSD kernel modules
- **No dynamic allocation** - Stack-based parsing
- **Binary search** - O(log n) key lookup (keys are sorted)
- **Iterator API** - Process entries one at a time

## Format

The parser handles the `key=value\n` format:

```
network=allow
trust=system
type=daemon
```

- Keys sorted alphabetically
- Keys cannot contain `=` or `\n`
- Values can contain `=` but not `\n`
- UTF-8 encoded

## API

### Iterator Pattern

```c
#include <maclabel_parser.h>

void process_label(const char *data, size_t len) {
    struct maclabel_parser parser;
    struct maclabel_entry entry;

    maclabel_parser_init(&parser, data, len);

    while (maclabel_parser_next(&parser, &entry)) {
        // entry.key (length: entry.key_len)
        // entry.value (length: entry.value_len)
        // Note: strings are NOT null-terminated
    }
}
```

### Direct Lookup

```c
const char *value;
size_t value_len;

// Binary search (O(log n), good for many entries)
if (maclabel_find(data, len, "network", &value, &value_len)) {
    if (maclabel_streq(value, value_len, "allow")) {
        // Network access allowed
    }
}

// Linear search (simpler, good for <10 entries)
if (maclabel_find_linear(data, len, "trust", &value, &value_len)) {
    // Found trust value
}
```

### Validation

```c
if (!maclabel_validate(data, len)) {
    // Malformed label data
    return EINVAL;
}
```

### Count Entries

```c
size_t count = maclabel_count(data, len);
```

## Kernel Module Example

```c
#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/mac.h>
#include <sys/extattr.h>

#include "maclabel_parser.h"

static int
my_policy_check_exec(struct ucred *cred, struct vnode *vp, ...)
{
    char buf[1024];
    ssize_t len;
    const char *value;
    size_t value_len;

    /* Read label from extended attribute */
    len = extattr_get_file(path, EXTATTR_NAMESPACE_SYSTEM,
                           "mac_network", buf, sizeof(buf));
    if (len < 0)
        return 0;  /* No label = allow */

    /* Validate format */
    if (!maclabel_validate(buf, len))
        return EINVAL;

    /* Check network permission */
    if (maclabel_find(buf, len, "network", &value, &value_len)) {
        if (maclabel_streq(value, value_len, "deny"))
            return EACCES;
    }

    return 0;
}
```

## String Comparison

Since entry strings are not null-terminated, use `maclabel_streq()`:

```c
if (maclabel_streq(entry.value, entry.value_len, "allow")) {
    // Value equals "allow"
}
```

## Performance

- **Iterator**: O(n) to process all entries
- **maclabel_find()**: O(log n) binary search
- **maclabel_find_linear()**: O(n) linear search
- **maclabel_count()**: O(n)
- **maclabel_validate()**: O(n)

For labels with fewer than ~10 entries, linear search may be faster due to lower overhead.

## Limits

- Binary search uses a stack array of 64 line pointers
- Labels with >64 entries fall back to linear search
- No limit on total label size (caller provides buffer)

## Building

The library is part of FreeBSDKit:

```bash
swift build --target CMacLabelParser
```

For kernel modules, copy the source files directly into your module.
