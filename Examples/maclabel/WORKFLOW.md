# Complete Workflow Example

This guide demonstrates a complete end-to-end workflow for using `maclabel`.

## Step 1: Create Configuration

Create `my-policy.json`:

```json
{
  "attributeName": "mac.labels",
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
    },
    {
      "path": "/usr/local/bin/my-daemon",
      "attributes": {
        "type": "daemon",
        "trust": "system",
        "network": "allow",
        "filesystem": "readwrite"
      }
    }
  ]
}
```

## Step 2: Validate Configuration (No Root Required)

```bash
$ maclabel validate my-policy.json
✓ All 3 file(s) exist
✓ Configuration is valid
```

**With verbose output:**

```bash
$ maclabel validate my-policy.json -v
Loaded 3 label(s)
Using attribute name: mac.labels
Validating all paths...
✓ All 3 file(s) exist
✓ Configuration is valid
```

**With JSON output:**

```bash
$ maclabel validate my-policy.json --json
{
  "attributeName" : "mac.labels",
  "success" : true,
  "totalFiles" : 3
}
```

## Step 3: Check Current Labels (Before Applying)

```bash
$ maclabel show my-policy.json
/bin/sh:
  (no labels)

/usr/bin/curl:
  (no labels)

/usr/local/bin/my-daemon:
  (no labels)
```

**Or with JSON:**

```bash
$ maclabel show my-policy.json --json
{
  "files" : [
    {
      "path" : "/bin/sh"
    },
    {
      "path" : "/usr/bin/curl"
    },
    {
      "path" : "/usr/local/bin/my-daemon"
    }
  ]
}
```

## Step 4: Apply Labels (Requires Root)

```bash
$ sudo maclabel apply my-policy.json -v
Loaded 3 label(s)
Using attribute name: mac.labels
Validating all paths...
Processing: /bin/sh
  ✓ Successfully labeled
Processing: /usr/bin/curl
  ✓ Successfully labeled
Processing: /usr/local/bin/my-daemon
  ✓ Successfully labeled

✓ Applied 3 label(s) successfully
```

**With JSON output:**

```bash
$ sudo maclabel apply my-policy.json --json
{
  "failedFiles" : 0,
  "results" : [
    {
      "path" : "/bin/sh",
      "previousLabel" : null,
      "success" : true
    },
    {
      "path" : "/usr/bin/curl",
      "previousLabel" : null,
      "success" : true
    },
    {
      "path" : "/usr/local/bin/my-daemon",
      "previousLabel" : null,
      "success" : true
    }
  ],
  "success" : true,
  "successfulFiles" : 3,
  "totalFiles" : 3
}
```

## Step 5: Verify Labels Were Applied Correctly

```bash
$ maclabel verify my-policy.json
✓ All 3 label(s) match configuration
```

**With verbose output:**

```bash
$ maclabel verify my-policy.json -v
Loaded 3 label(s)
Using attribute name: mac.labels
Validating all paths...
Verifying: /bin/sh
  ✓ Labels match
Verifying: /usr/bin/curl
  ✓ Labels match
Verifying: /usr/local/bin/my-daemon
  ✓ Labels match

✓ All 3 label(s) match configuration
```

**With JSON (detailed):**

```bash
$ maclabel verify my-policy.json --json
{
  "matchingFiles" : 3,
  "mismatchedFiles" : 0,
  "results" : [
    {
      "actual" : {
        "network" : "deny",
        "trust" : "system",
        "type" : "shell"
      },
      "expected" : {
        "network" : "deny",
        "trust" : "system",
        "type" : "shell"
      },
      "matches" : true,
      "mismatches" : [],
      "path" : "/bin/sh"
    },
    {
      "actual" : {
        "filesystem" : "read",
        "network" : "allow",
        "trust" : "user",
        "type" : "network_client"
      },
      "expected" : {
        "filesystem" : "read",
        "network" : "allow",
        "trust" : "user",
        "type" : "network_client"
      },
      "matches" : true,
      "mismatches" : [],
      "path" : "/usr/bin/curl"
    },
    {
      "actual" : {
        "filesystem" : "readwrite",
        "network" : "allow",
        "trust" : "system",
        "type" : "daemon"
      },
      "expected" : {
        "filesystem" : "readwrite",
        "network" : "allow",
        "trust" : "system",
        "type" : "daemon"
      },
      "matches" : true,
      "mismatches" : [],
      "path" : "/usr/local/bin/my-daemon"
    }
  ],
  "success" : true,
  "totalFiles" : 3
}
```

## Step 6: Show Current Labels

```bash
$ maclabel show my-policy.json
/bin/sh:
  network=deny
  trust=system
  type=shell

/usr/bin/curl:
  filesystem=read
  network=allow
  trust=user
  type=network_client

/usr/local/bin/my-daemon:
  filesystem=readwrite
  network=allow
  trust=system
  type=daemon
```

## Step 7: Verify with FreeBSD getextattr(8)

You can verify labels manually using FreeBSD's built-in tools:

```bash
$ getextattr -l system /bin/sh
mac.labels

$ getextattr system mac.labels /bin/sh
network=deny
trust=system
type=shell
```

## Step 8: Modify and Re-apply

Update `my-policy.json` to change curl's trust level:

```json
{
  "attributeName": "mac.labels",
  "labels": [
    {
      "path": "/usr/bin/curl",
      "attributes": {
        "type": "network_client",
        "trust": "untrusted",  # Changed from "user"
        "network": "allow",
        "filesystem": "read"
      }
    }
  ]
}
```

Re-apply:

```bash
$ sudo maclabel apply my-policy.json -v
Loaded 1 label(s)
Using attribute name: mac.labels
Validating all paths...
Processing: /usr/bin/curl
  Previous label: trust=user
network=allow
filesystem=read
type=network_client

  ✓ Successfully labeled

✓ Applied 1 label(s) successfully
```

Verify the change:

```bash
$ maclabel verify my-policy.json
✓ All 1 label(s) match configuration

$ maclabel show my-policy.json
/usr/bin/curl:
  filesystem=read
  network=allow
  trust=untrusted
  type=network_client
```

## Step 9: Use --no-overwrite

If you want to preserve existing labels:

```bash
# This will NOT overwrite the label on /usr/bin/curl
$ sudo maclabel apply my-policy.json --no-overwrite -v
Loaded 1 label(s)
Using attribute name: mac.labels
Validating all paths...
Processing: /usr/bin/curl
  Skipping (label exists and overwrite=false)

✓ Applied 0 label(s), skipped 1
```

## Step 10: Remove Labels

When you're done testing:

```bash
$ sudo maclabel remove my-policy.json -v
Loaded 3 label(s)
Using attribute name: mac.labels
Validating all paths...
Removing label from: /bin/sh
  ✓ Successfully removed
Removing label from: /usr/bin/curl
  ✓ Successfully removed
Removing label from: /usr/local/bin/my-daemon
  ✓ Successfully removed

✓ Removed 3 label(s) successfully
```

Verify they're gone:

```bash
$ maclabel show my-policy.json
/bin/sh:
  (no labels)

/usr/bin/curl:
  (no labels)

/usr/local/bin/my-daemon:
  (no labels)
```

## Error Handling Examples

### Missing File

```bash
$ cat missing-file.json
{
  "attributeName": "mac.labels",
  "labels": [
    {
      "path": "/nonexistent/file",
      "attributes": {"type": "test"}
    }
  ]
}

$ maclabel validate missing-file.json
✗ File not found: /nonexistent/file
Error: File not found at path: /nonexistent/file
```

### Invalid Attribute Characters

```bash
$ cat bad-attrs.json
{
  "attributeName": "mac.labels",
  "labels": [
    {
      "path": "/bin/sh",
      "attributes": {
        "bad=key": "value"  # Key contains '='
      }
    }
  ]
}

$ maclabel validate bad-attrs.json
Error: Key 'bad=key' contains forbidden character (=, newline, or null)
```

### Permission Denied (Non-root)

```bash
$ maclabel apply my-policy.json
Error: Operation not permitted (errno=1)
Failed to set extended attribute on /bin/sh

# Must use sudo:
$ sudo maclabel apply my-policy.json
✓ Applied 3 label(s) successfully
```

## Integration with Scripts

### Bash

```bash
#!/bin/bash
set -e

CONFIG="my-policy.json"

# Validate first
if ! maclabel validate "$CONFIG"; then
    echo "Configuration validation failed"
    exit 1
fi

# Apply labels
if ! sudo maclabel apply "$CONFIG"; then
    echo "Failed to apply labels"
    exit 1
fi

# Verify they were applied
if ! maclabel verify "$CONFIG"; then
    echo "Label verification failed"
    exit 1
fi

echo "Labels applied and verified successfully"
```

### JSON Output Parsing with jq

```bash
# Check if all files have labels
$ maclabel show config.json --json | \
  jq '.files[] | select(.labels == null) | .path'

# Count successful vs failed applications
$ sudo maclabel apply config.json --json | \
  jq '{success: .successfulFiles, failed: .failedFiles}'

# List files with mismatched labels
$ maclabel verify config.json --json | \
  jq '.results[] | select(.matches == false) | {path, mismatches}'
```

## Best Practices

1. **Always validate before applying**
   ```bash
   maclabel validate config.json && sudo maclabel apply config.json
   ```

2. **Use verbose mode during testing**
   ```bash
   sudo maclabel apply config.json -v
   ```

3. **Verify after applying**
   ```bash
   sudo maclabel apply config.json && maclabel verify config.json
   ```

4. **Use JSON output for automation**
   ```bash
   if maclabel validate config.json --json | jq -e '.success'; then
       sudo maclabel apply config.json
   fi
   ```

5. **Keep backups of configurations**
   ```bash
   cp my-policy.json my-policy.json.backup
   ```

6. **Test on non-critical files first**
   ```bash
   # Test with a single file
   cat > test.json <<EOF
   {
     "attributeName": "mac.test",
     "labels": [{"path": "/tmp/testfile", "attributes": {"test": "value"}}]
   }
   EOF

   touch /tmp/testfile
   sudo maclabel apply test.json -v
   maclabel verify test.json
   sudo maclabel remove test.json
   ```

## Troubleshooting

### Labels not visible with getextattr

Make sure you're using the correct attribute name:

```bash
# Wrong:
$ getextattr system mac.labels /bin/sh

# Right (use attributeName from config):
$ getextattr system mac.network /bin/sh
```

### Permission denied even as root

Check if extended attributes are supported on the filesystem:

```bash
$ mount | grep -E '(ufs|zfs)'
```

UFS and ZFS support extended attributes. Other filesystems may not.

### Labels disappear after reboot

Extended attributes are persistent on UFS/ZFS. If they disappear:
- Check filesystem type
- Check if filesystem is remounted
- Verify extended attribute support is enabled

## See Also

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed technical documentation
- [README.md](README.md) - Tool reference
- `getextattr(1)` - View extended attributes
- `setextattr(1)` - Set extended attributes manually
- `extattr(2)` - Extended attribute system calls
- `mac(4)` - MACF framework documentation
