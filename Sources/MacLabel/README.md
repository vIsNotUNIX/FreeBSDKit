# MacLabel Library

A Swift library for applying security labels to FreeBSD resources via extended attributes. Designed for integration with the Mandatory Access Control Framework (MACF).

## Overview

MacLabel provides:
- **Configuration-driven labeling** - Define labels in JSON, apply atomically
- **Capsicum integration** - Defense-in-depth via capability-restricted file descriptors
- **Extensible design** - Implement `Labelable` protocol for custom resource types
- **Validation** - All paths validated before any modifications

## Basic Usage

```swift
import MacLabel

// Load configuration from JSON
let config = try LabelConfiguration<FileLabel>.load(from: configFile)

// Create labeler and apply
var labeler = Labeler(configuration: config)
let results = try labeler.apply()

// Verify labels were applied correctly
let verification = try labeler.verify()
```

### Configuration Format

```json
{
  "attributeName": "mac_network",
  "labels": [
    {
      "path": "/usr/local/bin/myapp",
      "attributes": {
        "network": "allow",
        "trust": "system"
      }
    },
    {
      "path": "/usr/local/bin/*",
      "attributes": {
        "network": "deny",
        "trust": "user"
      }
    }
  ]
}
```

## Extension Points

The library is designed around the `Labelable` protocol. You can create custom label types for different resource types or encoding formats.

### The Labelable Protocol

```swift
public protocol Labelable: Codable {
    /// Resource identifier (file path, URL, etc.)
    var path: String { get }

    /// Security attributes as key-value pairs
    var attributes: [String: String] { get }

    /// Validate the resource exists
    func validate() throws

    /// Validate attribute format
    func validateAttributes() throws

    /// Encode attributes to wire format
    func encodeAttributes() throws -> Data
}
```

### What You Can Customize

| Method | Default Behavior | Override When |
|--------|-----------------|---------------|
| `validate()` | Check file exists | Custom existence check (URL reachable, DB row exists) |
| `validateAttributes()` | No `=`, `\n`, `\0` in keys | Custom validation rules |
| `encodeAttributes()` | `key=value\n` format | JSON, protobuf, binary encoding |

## Example: Custom Label Types

### 1. JSON-Encoded Attributes

Store attributes as JSON instead of `key=value\n`:

```swift
struct JSONFileLabel: Labelable {
    let path: String
    let attributes: [String: String]

    func validate() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LabelError.fileNotFound(path)
        }
    }

    func encodeAttributes() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(attributes)
    }
}
```

### 2. Typed Attributes with Validation

Enforce specific attribute schemas:

```swift
struct NetworkPolicyLabel: Labelable {
    let path: String
    let attributes: [String: String]

    // Required attributes for this policy type
    static let requiredKeys = ["network", "trust"]
    static let validNetworkValues = ["allow", "deny", "local_only"]
    static let validTrustValues = ["system", "user", "untrusted"]

    func validate() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LabelError.fileNotFound(path)
        }
    }

    func validateAttributes() throws {
        // Check required keys present
        for key in Self.requiredKeys {
            guard attributes[key] != nil else {
                throw LabelError.invalidAttribute("Missing required key: \(key)")
            }
        }

        // Validate enum values
        if let network = attributes["network"],
           !Self.validNetworkValues.contains(network) {
            throw LabelError.invalidAttribute(
                "Invalid network value '\(network)'. Must be: \(Self.validNetworkValues)"
            )
        }

        if let trust = attributes["trust"],
           !Self.validTrustValues.contains(trust) {
            throw LabelError.invalidAttribute(
                "Invalid trust value '\(trust)'. Must be: \(Self.validTrustValues)"
            )
        }
    }

    func encodeAttributes() throws -> Data {
        try validateAttributes()

        // Use default key=value encoding
        var result = ""
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            result += "\(key)=\(value)\n"
        }
        return result.data(using: .utf8)!
    }
}
```

### 3. Binary/Compact Encoding

For performance-critical policies:

```swift
struct CompactLabel: Labelable {
    let path: String
    let attributes: [String: String]

    // Map string values to compact integers
    static let networkCodes: [String: UInt8] = [
        "deny": 0, "allow": 1, "local_only": 2
    ]
    static let trustCodes: [String: UInt8] = [
        "untrusted": 0, "user": 1, "system": 2
    ]

    func validate() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LabelError.fileNotFound(path)
        }
    }

    func encodeAttributes() throws -> Data {
        var data = Data()

        // Version byte
        data.append(0x01)

        // Encode network as single byte
        if let network = attributes["network"],
           let code = Self.networkCodes[network] {
            data.append(code)
        } else {
            data.append(0xFF) // unset
        }

        // Encode trust as single byte
        if let trust = attributes["trust"],
           let code = Self.trustCodes[trust] {
            data.append(code)
        } else {
            data.append(0xFF) // unset
        }

        return data
    }
}
```

### 4. URL-Based Resources

Label network endpoints instead of files:

```swift
struct EndpointLabel: Labelable {
    let path: String  // URL string
    let attributes: [String: String]

    func validate() throws {
        guard let url = URL(string: path) else {
            throw LabelError.invalidConfiguration("Invalid URL: \(path)")
        }

        // Optionally verify endpoint is reachable
        guard url.scheme == "https" || url.scheme == "http" else {
            throw LabelError.invalidConfiguration("URL must be HTTP(S): \(path)")
        }
    }

    func encodeAttributes() throws -> Data {
        // Standard encoding works fine
        var result = ""
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            result += "\(key)=\(value)\n"
        }
        return result.data(using: .utf8)!
    }
}
```

**Note**: The `Labeler` struct is file-specific (uses `open()`, `ExtendedAttributes`). For non-file resources, use `Labelable` directly with your own storage mechanism.

## Wire Format

The default encoding produces:

```
key1=value1
key2=value2
key3=value3
```

- Keys sorted alphabetically for deterministic output
- UTF-8 encoded
- Keys cannot contain `=`, `\n`, or `\0`
- Values cannot contain `\n` or `\0`
- Values CAN contain `=` (parsed with `maxSplits: 1`)

This format is designed for easy parsing in C kernel code:

```c
// Example kernel code to parse labels
char *line = label_data;
while (*line) {
    char *eq = strchr(line, '=');
    char *nl = strchr(line, '\n');
    // key is [line, eq), value is [eq+1, nl)
    line = nl + 1;
}
```

## Recursive Patterns

Paths ending with `/*` apply labels recursively:

```json
{
  "path": "/usr/local/bin/*",
  "attributes": {"trust": "user"}
}
```

This labels all regular files in `/usr/local/bin/` and subdirectories.

## Duplicate Handling

When multiple labels match the same file, **last wins**:

```json
{
  "labels": [
    {"path": "/usr/local/bin/*", "attributes": {"trust": "user"}},
    {"path": "/usr/local/bin/special", "attributes": {"trust": "system"}}
  ]
}
```

The file `/usr/local/bin/special` gets `trust=system` (the explicit entry overrides the pattern).

Use `labeler.detectDuplicates()` to find overlaps before applying.

## MACF Integration

Labels are stored in FreeBSD extended attributes:
- **Namespace**: `system` (requires root)
- **Attribute name**: From `attributeName` in config

Your MACF kernel module reads these via `mac_vnode_check_*` hooks:

```c
static int
my_policy_check_exec(struct ucred *cred, struct vnode *vp,
                     struct label *vplabel, ...)
{
    char buf[1024];
    ssize_t len = extattr_get_file(path, EXTATTR_NAMESPACE_SYSTEM,
                                   "mac_network", buf, sizeof(buf));
    // Parse and enforce policy based on label
}
```

## Error Handling

All operations validate before modifying:

```swift
do {
    try labeler.apply()
} catch LabelError.fileNotFound(let path) {
    // A file in the config doesn't exist
} catch LabelError.invalidAttribute(let msg) {
    // Attribute format is invalid
} catch LabelError.invalidConfiguration(let msg) {
    // Config file is malformed
}
```

If validation fails, **no labels are modified** (atomic behavior).

## Thread Safety

- `LabelConfiguration` is `Sendable`
- `Labeler` is a struct (value type) - copy for concurrent use
- File operations use Capsicum-restricted descriptors for isolation
