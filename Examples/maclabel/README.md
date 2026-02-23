# maclabel Configuration Examples

This directory contains example configuration files for the `maclabel` tool.

## Files

### minimal.json
Minimal configuration with a single file label. Use this as a starting point for testing.

```bash
# Validate the configuration
maclabel validate Examples/maclabel/minimal.json

# Show current labels (won't need root)
maclabel show Examples/maclabel/minimal.json

# Apply labels (requires root for system namespace)
sudo maclabel apply Examples/maclabel/minimal.json
```

### system-binaries.json
Example policy for common system binaries with different trust levels and access controls.

Demonstrates:
- Different binary types (shell, utility, network_client)
- Trust levels (system, user)
- Network access controls (allow, deny)
- Filesystem access (read)

### network-policy.json
Network-specific policy using a dedicated attribute name (`mac.network`).

Demonstrates:
- Using a custom attribute name for policy separation
- Network-specific attributes (protocols, ports, direction)
- Server vs client configurations

## JSON Output

All commands support `--json` flag for machine-readable output:

```bash
# Validate with JSON output
maclabel validate Examples/maclabel/minimal.json --json

# Apply with JSON output
sudo maclabel apply Examples/maclabel/minimal.json --json

# Verify with JSON output
maclabel verify Examples/maclabel/minimal.json --json

# Show with JSON output
maclabel show Examples/maclabel/minimal.json --json
```

## Configuration Format

```json
{
  "attributeName": "mac.labels",
  "labels": [
    {
      "path": "/absolute/path/to/file",
      "attributes": {
        "key1": "value1",
        "key2": "value2"
      }
    }
  ]
}
```

### Field Constraints

**attributeName** (required):
- Must not be empty
- Only allows: `A-Za-z0-9._-`
- No whitespace or control characters
- Maximum 255 bytes

**path** (required):
- Must be absolute path
- File must exist
- No null bytes

**attributes** (required):
- Keys: No `=`, newlines, or null bytes; must not be empty
- Values: Can contain `=`; no newlines or null bytes; may be empty

## Testing

Use the minimal.json file for testing:

```bash
# 1. Validate (no root needed)
maclabel validate Examples/maclabel/minimal.json

# 2. Apply labels (root required for system namespace)
sudo maclabel apply Examples/maclabel/minimal.json --verbose

# 3. Verify labels match configuration
maclabel verify Examples/maclabel/minimal.json

# 4. Show current labels
maclabel show Examples/maclabel/minimal.json

# 5. Remove labels (root required)
sudo maclabel remove Examples/maclabel/minimal.json
```

## Multiple Policies

Different MACF policies can use different attribute names to avoid conflicts:

- `mac.labels` - General purpose policy
- `mac.network` - Network access policy
- `mac.filesystem` - Filesystem access policy
- `mac.custom` - Custom policy

Each policy can have its own configuration file and attribute name.
