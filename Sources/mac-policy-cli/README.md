# maclabel - MACF Binary Labeling Tool

A command-line tool for applying security labels to binaries and files using FreeBSD extended attributes. Designed for use with MACF (Mandatory Access Control Framework) policies.

## Overview

`maclabel` reads a JSON configuration file describing which files should be labeled and with what attributes, then applies those labels to the filesystem using extended attributes in the `system` namespace.

Labels are stored in a configurable extended attribute (e.g., `system.mac_labels`) in a simple, C-parseable format.

## Installation

```bash
swift build -c release --product maclabel
sudo cp .build/release/maclabel /usr/local/bin/
```

## Usage

```bash
maclabel <command> <config-file> [options]
```

### Commands

- `validate` - Validate configuration file and check all paths exist
- `apply` - Apply labels from configuration file to files
- `verify` - Verify that labels are correctly applied to files
- `remove` - Remove labels from files in configuration
- `show` - Display current labels for files in configuration

### Options

- `-v, --verbose` - Print detailed output
- `--no-overwrite` - Don't overwrite existing labels (apply only)
- `--json` - Machine-readable output

### Examples

```bash
# Validate configuration before applying
maclabel validate labels.json

# Apply labels (requires root)
sudo maclabel apply labels.json -v

# Verify labels match configuration
maclabel verify labels.json

# Show current labels
maclabel show labels.json

# Remove all labels (requires root)
sudo maclabel remove labels.json

# Apply without overwriting existing labels
sudo maclabel apply labels.json --no-overwrite
```

## Configuration File Format

The configuration is a JSON file with the following structure:

```json
{
  "attributeName": "mac_labels",
  "labels": [
    {
      "path": "/bin/sh",
      "attributes": {
        "type": "shell",
        "trust": "system",
        "network": "deny"
      }
    },
    {
      "path": "/usr/bin/curl",
      "attributes": {
        "type": "network_client",
        "trust": "user",
        "network": "allow",
        "filesystem": "read"
      }
    }
  ]
}
```

### Fields

- `attributeName` (string, **required**) - Name of the extended attribute to use
  - This allows different MACF policies to use different attribute names
  - Common values: `"mac_labels"`, `"mac_policy"`, `"mac_network"`
  - **Important**: Dots (`.`) are NOT allowed - FreeBSD extattr rejects them with EINVAL
  - Only alphanumeric characters, underscores, and hyphens: `A-Za-z0-9_-`
  - Will be used as `system.<attributeName>` in extended attributes
- `labels` (array) - List of file labels to apply
  - `path` (string) - Absolute path to the file, or a directory pattern ending with `/*`
  - `attributes` (object) - Key-value pairs of security attributes

### Recursive Directory Labeling

Use `/*` at the end of a path to recursively label all files in a directory:

```json
{
  "attributeName": "mac_labels",
  "labels": [
    {
      "path": "/usr/local/bin/*",
      "attributes": {
        "type": "local_binary",
        "trust": "user"
      }
    }
  ]
}
```

This will apply the same label to all files in `/usr/local/bin/` and all subdirectories.

When validating, the tool shows how patterns expand:

```bash
$ maclabel validate config.json -v
Loaded 1 label(s)
Using attribute name: mac_labels
Validating configuration...
  /usr/local/bin/* (recursive pattern, 42 files)
    → /usr/local/bin/app1
    → /usr/local/bin/app2
    → /usr/local/bin/subdir/tool1
    ...
✓ Configuration is valid
```

### Attribute Constraints

- Keys and values must not contain `=` or newline characters
- Keys and values are arbitrary strings (application-defined)
- Common attributes might include:
  - `type` - Binary type (shell, utility, network_client, etc.)
  - `trust` - Trust level (system, user, untrusted)
  - `network` - Network access (allow, deny)
  - `filesystem` - Filesystem access (read, write, none)

## Wire Format

Labels are stored as newline-separated key-value pairs:

```
key1=value1
key2=value2
key3=value3
```

This format is designed to be easily parseable from C code.

## Reading Labels from C

Here's how a MACF policy or other C code can read the labels:

**Note**: Replace `"mac_labels"` with the attribute name specified in your configuration file.

```c
#include <sys/types.h>
#include <sys/extattr.h>
#include <stdio.h>
#include <string.h>

int read_mac_labels(const char *path, const char *attr_name) {
    char buf[4096];
    ssize_t len = extattr_get_file(
        path,
        EXTATTR_NAMESPACE_SYSTEM,
        attr_name,  // e.g., "mac_labels", "mac_network", etc.
        buf,
        sizeof(buf)
    );

    if (len < 0) {
        // No labels or error
        return -1;
    }

    buf[len] = '\0';

    // Parse newline-separated key=value pairs
    char *line = strtok(buf, "\n");
    while (line != NULL) {
        char *eq = strchr(line, '=');
        if (eq != NULL) {
            *eq = '\0';
            const char *key = line;
            const char *value = eq + 1;

            printf("  %s = %s\n", key, value);

            // Check specific attributes
            if (strcmp(key, "network") == 0 && strcmp(value, "deny") == 0) {
                // Enforce network deny policy
            }
        }
        line = strtok(NULL, "\n");
    }

    return 0;
}
```

## Security Features

### Capsicum Integration

All operations use FreeBSD's Capsicum capability system for defense-in-depth:

- **Configuration files** are opened with restricted rights (read-only)
- **File descriptors** are wrapped in `FileCapability` with minimal rights:
  - `.read` - Read file contents
  - `.fstat` - Get file metadata
  - `.seek` - Position seeking
  - `.extattrGet`, `.extattrSet`, `.extattrDelete` - As needed for operation
- **Kernel enforcement** prevents unauthorized operations even if code is exploited
- **TOCTOU protection** via file descriptor-based operations

### Privilege Separation

- `validate`, `verify`, `show` - Can run as regular user
- `apply`, `remove` - Require root for system namespace access

This encourages a safe workflow:
```bash
# 1. Validate as user
maclabel validate config.json

# 2. Apply as root only after validation
sudo maclabel apply config.json
```

### JSON Output

All commands support `--json` for machine-readable output:

```bash
maclabel validate config.json --json
maclabel apply config.json --json
maclabel verify config.json --json
```

Output includes success/failure status and detailed results.

## Requirements

- FreeBSD system with extended attribute support
- Root privileges to set `system` namespace attributes
- Swift 6.2 or later
- Capsicum support (enabled by default on FreeBSD 10.0+)

## Extended Attributes

The tool uses the FreeBSD extended attribute API:

- **Namespace**: `EXTATTR_NAMESPACE_SYSTEM` (2)
- **Attribute Name**: Specified in configuration (`attributeName` field)
- **Full Path**: `system.<attributeName>`

You can view labels manually using:

```bash
# List extended attributes (replace 'mac_labels' with your attributeName)
getextattr -l system mac_labels /bin/sh

# Get extended attribute value
getextattr system mac_labels /bin/sh

# Or for a different policy:
getextattr system mac_network /usr/bin/curl
```

## Error Handling

The tool validates:

1. Configuration file is valid JSON
2. All paths exist (unless `--skip-validation` is used)
3. Attribute keys/values don't contain forbidden characters
4. Extended attribute operations succeed

Errors are reported with descriptive messages and appropriate exit codes.

## Integration with MACF

To use these labels in a MACF policy:

1. Label binaries using `maclabel` with your policy's attribute name
2. Write a MACF kernel module that reads `system.<attributeName>` (e.g., `system.mac_mylabels`)
3. Parse the label format in your policy's label hooks
4. Enforce policy based on the attributes

**Note**: Different policies can use different attribute names by specifying different `attributeName` values in their configuration files.

Example MACF hooks to implement:

- `mpo_vnode_check_exec` - Check labels before executing
- `mpo_vnode_check_open` - Check labels before opening files
- `mpo_socket_check_connect` - Check `network` attribute

## License

BSD-2-Clause

## See Also

- `extattr(2)` - FreeBSD extended attributes
- `mac(4)` - FreeBSD Mandatory Access Control
- `mac(9)` - MAC Framework kernel interfaces
