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
        { "name": "latency_ns", "type": "UInt64" }
      ]
    }
  ]
}
```

### 2. Generate Swift Code

```bash
swift run dprobes-gen myapp.dprobes --output-dir .
```

This generates:
- `myapp_probes.swift` - Swift probe functions with IS-ENABLED checks
- `myapp_provider.d` - DTrace provider definition

### 3. Use Probes in Your Code

```swift
import Foundation

// Fire probes with zero overhead when not tracing
Myapp.requestStart(path: req.path, method: 1)

// Arguments are only evaluated when DTrace is active
Myapp.requestDone(
    path: req.path,
    status: 200,
    latency_ns: calculateLatency()  // Not called when not tracing
)
```

### 4. Build Options

**Option A: Development/Stubs (No DTrace)**

Build with stub implementations for development:
```bash
swift build --product dprobes-demo
```

The stubs return false for IS-ENABLED checks, so probes have zero overhead.

**Option B: Production (With DTrace)**

1. Compile the provider header and object:
   ```bash
   dtrace -h -s myapp_provider.d  # Generates myapp_provider.h
   dtrace -G -s myapp_provider.d -o myapp_provider.o  # Requires object files
   ```

2. Link the provider with your binary (requires custom build setup)

## Tracing

Once running with full DTrace support:

```bash
# Trace all request probes
sudo dtrace -n 'myapp:::request* { printf("%s\n", copyinstr(arg0)); }'

# Trace with timing
sudo dtrace -n 'myapp:::request_done {
    printf("%s status=%d latency=%dms\n",
           copyinstr(arg0), arg1, arg2/1000000);
}'

# Count cache hits vs misses
sudo dtrace -n 'myapp:::cache* { @[probename] = count(); }'
```

## Supported Types

| Swift Type | DTrace Type | Notes |
|------------|-------------|-------|
| Int8-64    | int8-64_t   | Direct conversion |
| UInt8-64   | uint8-64_t  | Direct conversion |
| Bool       | int32_t     | 0 or 1 |
| String     | char *      | Passed via withCString |
| UnsafePointer | uintptr_t | Pointer address |

## Files

- `myapp.dprobes` - Probe definition file (input)
- `myapp_probes.swift` - Generated Swift code
- `myapp_provider.d` - Generated DTrace provider definition
- `main.swift` - Example application
- `stubs.c` - Stub implementations for building without DTrace

## Performance

The generated probe functions use:
- `@inlinable` - Enables cross-module inlining
- `@autoclosure` - Defers argument evaluation
- IS-ENABLED check first - Guards all argument evaluation

This means:
```swift
Myapp.requestStart(path: expensiveStringOperation(), method: 1)
```

The `expensiveStringOperation()` is **never called** unless DTrace is actively tracing the probe.
