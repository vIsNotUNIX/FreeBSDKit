# DProbes Example - Swift USDT Probes for FreeBSD

This example demonstrates using USDT (Userland Statically Defined Tracing) probes in Swift on FreeBSD.

## Overview

DProbes provides zero-overhead instrumentation for Swift applications. When DTrace is not actively tracing:
- IS-ENABLED checks are extremely fast (single memory read)
- Probe arguments are never evaluated (thanks to `@autoclosure`)
- Total overhead: ~1-2 nanoseconds per probe point

## Quick Start

### 1. Define Your Probes

Create a `.dprobes` file with your provider definition (JSON format):

```json
{
  "name": "myapp",
  "stability": "Evolving",
  "probes": [
    {
      "name": "request_start",
      "docs": "Fires when HTTP request begins",
      "args": [
        { "name": "path", "type": "String" },
        { "name": "method", "type": "Int32" }
      ]
    },
    {
      "name": "request_done",
      "args": [
        { "name": "path", "type": "String" },
        { "name": "status", "type": "Int32" },
        { "name": "latencyNs", "type": "UInt64" }
      ]
    }
  ]
}
```

### 2. Generate Swift Code

```bash
dprobes myapp.dprobes -o .
```

This generates:
- `myapp_probes.swift` - Swift probe functions with IS-ENABLED checks
- `myapp_provider.d` - DTrace provider definition

Options:
- `--swift-only` - Generate only Swift code
- `--dtrace-only` - Generate only DTrace provider
- `--version` - Show version

### 3. Use Probes in Your Code

```swift
// Fire probes with zero overhead when not tracing
MyappProbes.requestStart(path: req.path, method: 1)

// Arguments are only evaluated when DTrace is active
MyappProbes.requestDone(
    path: req.path,
    status: 200,
    latencyNs: calculateLatency()  // Not called when not tracing
)
```

### 4. Build with DTrace Support

1. Compile your Swift code to object files
2. Compile the provider:
   ```bash
   dtrace -G -s myapp_provider.d your_code.o -o myapp_provider.o
   ```
3. Link everything together:
   ```bash
   swiftc your_code.o myapp_provider.o -o myapp
   ```

## Tracing

Once running with full DTrace support:

```bash
# List available probes (provider gets PID suffix)
sudo dtrace -l -n 'myapp*:::'

# Trace all request probes
sudo dtrace -n 'myapp*:::request* { printf("%s\n", copyinstr(arg0)); }'

# Trace with timing
sudo dtrace -n 'myapp*:::request__done {
    printf("%s status=%d latency=%dms\n",
           copyinstr(arg0), arg1, arg2/1000000);
}'

# Count cache hits vs misses
sudo dtrace -n 'myapp*:::cache* { @[probename] = count(); }'
```

Note: USDT provider names get a PID suffix at runtime (e.g., `myapp1234`), so use `myapp*` wildcards.

## Supported Types

| Swift Type | DTrace Type | Notes |
|------------|-------------|-------|
| Int8       | int8_t      | Direct conversion |
| Int16      | int16_t     | Direct conversion |
| Int32      | int32_t     | Direct conversion |
| Int64, Int | int64_t     | Direct conversion |
| UInt8      | uint8_t     | Direct conversion |
| UInt16     | uint16_t    | Direct conversion |
| UInt32     | uint32_t    | Direct conversion |
| UInt64, UInt | uint64_t  | Direct conversion |
| Bool       | int32_t     | 0 or 1 |
| String     | char *      | Passed via withCString |

## Constraints

- Provider/probe names: letters, numbers, underscore; max 64 chars
- Arguments: max 10 per probe
- Argument names: cannot be Swift keywords

## Performance

The generated probe functions use:
- `@inlinable` - Enables cross-module inlining
- `@autoclosure` - Defers argument evaluation
- IS-ENABLED check first - Guards all argument evaluation

This means:
```swift
MyappProbes.requestStart(path: expensiveStringOperation(), method: 1)
```

The `expensiveStringOperation()` is **never called** unless DTrace is actively tracing the probe.

## Files

- `myapp.dprobes` - Example probe definition
