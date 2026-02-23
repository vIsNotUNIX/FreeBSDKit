# maclabel Tool Architecture

## Overview

The `maclabel` tool applies security labels to files using FreeBSD extended attributes. It's designed for use with MACF (Mandatory Access Control Framework) policies.

## How It Works

### 1. Configuration Loading

```
User → maclabel validate config.json
   ↓
loadConfiguration(path: "config.json")
   ↓
open(O_RDONLY | O_CLOEXEC)  [filesystem namespace required]
   ↓
FileCapability(rawFd)  [wrap descriptor]
   ↓
capability.limit(rights: [.read, .fstat, .seek])  [Capsicum restriction]
   ↓
LabelConfiguration.load(from: capability)
   ↓
descriptor.stat()  [check file type, size]
   ↓
descriptor.readExact(size)  [read complete file]
   ↓
JSONDecoder().decode()  [parse JSON]
   ↓
validateAttributeName()  [validate attribute name format]
   ↓
validateAttributes()  [validate all label attributes]
   ↓
Return validated configuration
```

**Key Points**:
- File opened once, validated via same descriptor (TOCTOU protection)
- Capsicum restricts descriptor to read-only operations
- All file I/O goes through Descriptor API (handles EINTR, buffering)
- Early validation fails fast before any filesystem modifications

### 2. Path Validation

```
maclabel validate config.json
   ↓
Labeler.validateAll()
   ↓
For each label in config:
    label.validate()  [check file exists]
   ↓
Report results
```

**Safety**: If ANY file is missing, entire operation fails. Prevents partial policy application.

### 3. Label Application

```
maclabel apply config.json
   ↓
Labeler.apply()
   ↓
validateAll()  [ensure all files exist first]
   ↓
For each label:
    applyTo(label)
       ↓
    ExtendedAttributes.get(path, namespace: .system, name: attrName)
       ↓
    Check if label exists and overwrite settings
       ↓
    label.encodeAttributes()  [validate and encode as key=value pairs]
       ↓
    ExtendedAttributes.set(path, namespace: .system, name: attrName, data)
       ↓
    Return LabelingResult(success/failure)
   ↓
Report all results
```

**Privileges**: Requires root to set `system` namespace attributes.

### 4. Label Verification

```
maclabel verify config.json
   ↓
Labeler.verify()
   ↓
validateAll()
   ↓
For each label:
    Get current label from filesystem
       ↓
    Parse label data
       ↓
    Compare expected vs actual attributes
       ↓
    Report mismatches (missing keys, extra keys, wrong values)
   ↓
Report all results
```

### 5. Label Display

```
maclabel show config.json
   ↓
Labeler.show()
   ↓
validateAll()
   ↓
For each file in config:
    Get current label from filesystem
       ↓
    Return raw label string or nil
   ↓
Display all labels
```

### 6. Label Removal

```
maclabel remove config.json
   ↓
Labeler.remove()
   ↓
validateAll()
   ↓
For each file:
    ExtendedAttributes.delete(path, namespace: .system, name: attrName)
       ↓
    Return result (ENOATTR is not an error - idempotent)
   ↓
Report all results
```

## Security Model

### Defense in Depth Layers

1. **Input Validation**
   - JSON schema validation
   - Attribute name character set restrictions
   - Key/value format validation
   - Path validation (no null bytes)

2. **Capsicum Capability Restrictions**
   - Config file descriptor limited to `.read`, `.fstat`, `.seek`
   - No write operations possible even if exploit occurs
   - Kernel-enforced at system call level

3. **TOCTOU Protection**
   - File opened once, used throughout
   - Validation and reading use same descriptor
   - fstat() on descriptor ensures properties can't change

4. **Privilege Separation**
   - Only `apply` and `remove` require root
   - `validate`, `verify`, `show` work as regular user
   - Encourages validate-before-apply workflow

5. **Atomic Safety**
   - All files validated before any modifications
   - Single file failure aborts entire operation
   - Prevents partial policy application

### Capsicum Lifecycle

This tool does NOT currently enter Capsicum capability mode, but it's designed to support it:

**Current Behavior** (Before Capability Mode):
1. Open config file by path ✓
2. Restrict descriptor rights ✓
3. Load and parse config ✓
4. Open/modify labeled files by path ✓
5. Full filesystem namespace available ✓

**Future Capability Mode Support**:
1. Open config file by path (must be before cap_enter)
2. Restrict descriptor rights
3. Load and parse config
4. cap_enter() → Enter capability mode
5. Can only use pre-opened descriptors
6. No new path-based opens allowed
7. Would require:
   - Pre-opening all labeled file descriptors
   - Passing descriptors instead of paths to ExtendedAttributes
   - Using fd-based extattr operations

## Data Flow

### Configuration File → Memory

```
config.json (JSON)
   ↓ [read via FileCapability]
LabelConfiguration<FileLabel>
   - attributeName: String
   - labels: [FileLabel]
        - path: String
        - attributes: [String: String]
```

### Memory → Extended Attributes

```
FileLabel.attributes
   {"type": "shell", "trust": "system"}
   ↓ [encodeAttributes()]
"trust=system\ntype=shell\n"  (sorted by key)
   ↓ [ExtendedAttributes.set()]
system.mac.labels (extended attribute on /bin/sh)
```

### Extended Attributes → Output

**Human-readable** (`--verbose` or default):
```
/bin/sh:
  trust=system
  type=shell
```

**Machine-readable** (`--json`):
```json
{
  "files": [
    {
      "path": "/bin/sh",
      "labels": {
        "trust": "system",
        "type": "shell"
      }
    }
  ]
}
```

## Error Handling

### Configuration Errors
- **Invalid JSON**: JSON parsing error with line/column
- **Missing attributeName**: Validation error
- **Invalid attribute name**: Character set validation error
- **File too large**: Size limit error (> 10MB)
- **Not a regular file**: File type error

### Runtime Errors
- **File not found**: LabelError.fileNotFound(path)
- **Permission denied**: ExtAttr operation errno
- **Invalid attributes**: Forbidden characters in key/value
- **Partial failure**: Some files succeed, some fail (all reported)

### Exit Codes
- **0**: Success (all operations succeeded)
- **1**: Failure (at least one operation failed)
- Errors are reported even in JSON mode

## Label Format

### Wire Format
```
key1=value1\n
key2=value2\n
key3=value3\n
```

**Properties**:
- Keys sorted alphabetically (deterministic output)
- Newline-terminated
- Can be parsed in C with strtok()
- No escaping (forbidden characters rejected at validation)

### Constraints
- **Keys**: Non-empty, no `=`, `\n`, `\0`
- **Values**: Can contain `=`, no `\n`, `\0`, can be empty
- Validated at multiple stages:
  1. JSON parsing
  2. validateAttributes() when loading config
  3. encodeAttributes() when applying

## JSON Output Schema

All commands support `--json` for structured output:

### ValidateOutput
```json
{
  "success": true,
  "totalFiles": 5,
  "attributeName": "mac.labels",
  "error": null
}
```

### ApplyOutput / RemoveOutput
```json
{
  "success": true,
  "totalFiles": 5,
  "successfulFiles": 5,
  "failedFiles": 0,
  "results": [
    {
      "path": "/bin/sh",
      "success": true,
      "error": null,
      "previousLabel": "trust=user\n"
    }
  ]
}
```

### VerifyOutput
```json
{
  "success": true,
  "totalFiles": 5,
  "matchingFiles": 5,
  "mismatchedFiles": 0,
  "results": [
    {
      "path": "/bin/sh",
      "matches": true,
      "expected": {"trust": "system"},
      "actual": {"trust": "system"},
      "error": null,
      "mismatches": []
    }
  ]
}
```

### ShowOutput
```json
{
  "files": [
    {
      "path": "/bin/sh",
      "labels": {"trust": "system", "type": "shell"},
      "error": null
    }
  ]
}
```

## Integration with MACF Policies

### Reading Labels in C

```c
#include <sys/extattr.h>

// Read label (use attribute name from config)
char buf[4096];
ssize_t len = extattr_get_file(
    "/bin/sh",
    EXTATTR_NAMESPACE_SYSTEM,
    "mac.labels",  // From config attributeName
    buf,
    sizeof(buf)
);

// Parse newline-separated key=value pairs
char *line = strtok(buf, "\n");
while (line) {
    char *eq = strchr(line, '=');
    if (eq) {
        *eq = '\0';
        const char *key = line;
        const char *value = eq + 1;

        // Check attributes
        if (strcmp(key, "network") == 0 &&
            strcmp(value, "deny") == 0) {
            // Deny network access
        }
    }
    line = strtok(NULL, "\n");
}
```

### MACF Hook Integration

```c
static int
my_policy_vnode_check_exec(struct ucred *cred,
                           struct vnode *vp,
                           struct label *vplabel,
                           /* ... */)
{
    char labels[4096];
    ssize_t len = extattr_get_vnode(
        vp,
        EXTATTR_NAMESPACE_SYSTEM,
        "mac.labels",  // Configured attribute name
        labels,
        sizeof(labels)
    );

    if (len > 0) {
        // Parse and enforce policy
    }

    return 0;
}
```

## Testing Strategy

### Unit Tests Needed

1. **Configuration Loading**
   - [ ] Valid JSON parsing
   - [ ] Invalid JSON (syntax errors)
   - [ ] Missing required fields
   - [ ] Invalid attribute names (forbidden chars)
   - [ ] File too large (> 10MB)
   - [ ] Empty file
   - [ ] Not a regular file (directory, socket, etc.)

2. **Attribute Validation**
   - [ ] Valid attributes
   - [ ] Keys with `=`, `\n`, `\0`
   - [ ] Values with `\n`, `\0`
   - [ ] Empty keys (invalid)
   - [ ] Empty values (valid)

3. **Capsicum Restrictions**
   - [ ] Read-restricted descriptor can read
   - [ ] Read-restricted descriptor cannot write
   - [ ] Rights violations are detected

4. **Label Operations**
   - [ ] Apply to non-existent file fails
   - [ ] Apply creates label
   - [ ] Apply overwrites existing label
   - [ ] Apply with --no-overwrite preserves label
   - [ ] Verify detects mismatches
   - [ ] Remove is idempotent (ENOATTR ok)

5. **Error Handling**
   - [ ] Permission denied handled gracefully
   - [ ] Partial failures reported correctly
   - [ ] JSON output includes errors

## Future Enhancements

1. **Full Capsicum Mode**
   - Pre-open all file descriptors
   - Enter capability mode after configuration load
   - Use fd-based ExtendedAttributes operations

2. **Batch Operations**
   - Parallel label application
   - Progress reporting
   - Rollback on failure

3. **Label Templating**
   - Wildcard paths
   - Computed attributes
   - Include/extend other configs

4. **Audit Logging**
   - Syslog integration
   - Change tracking
   - Who/when/what logging
