# FPC Demo

A comprehensive demo demonstrating FPC (FreeBSD Process Communication) IPC capabilities over FreeBSD SOCK_SEQPACKET Unix domain sockets.

## Building

```bash
swift build --product fpc-demo
```

## Running

### Quick Test (in-process socketpair)
```bash
.build/debug/fpc-demo pair
```

### Full Test Suite (separate processes)

**Terminal 1 - Start server:**
```bash
.build/debug/fpc-demo server /tmp/fpc-test.sock
```

**Terminal 2 - Run client:**
```bash
.build/debug/fpc-demo client /tmp/fpc-test.sock
```

### Automated (single command)
```bash
.build/debug/fpc-demo server /tmp/fpc-test.sock &
sleep 0.5
.build/debug/fpc-demo client /tmp/fpc-test.sock
```

## Test Coverage

### Pair Tests (in-process socketpair)

| Test | What it Verifies |
|------|-----------------|
| Request/Reply (A→B) | Correlation ID routing, `request()` blocks for reply |
| Request/Reply (B→A) | **Bidirectional RPC** - both endpoints can initiate requests |
| Large Payload (64KB) | Data integrity with byte pattern verification |

### Client/Server Tests (separate processes)

| Test | What it Verifies |
|------|-----------------|
| **1. Request/Reply** | Correlation ID routing across process boundaries |
| **2. Large Message (100KB)** | Automatic OOL via anonymous shared memory |
| **3. Multiple Descriptors** | SCM_RIGHTS passing 3 file descriptors |
| **4. Unsolicited Stream** | `incoming()` async iteration for fire-and-forget |
| **5. Reply Isolation** | Replies route to `request()`, not `incoming()` |

## API Coverage

| FPC API | Test Coverage |
|---------|---------------|
| `FPCEndpoint.pair()` | Pair tests |
| `FPCClient.connect()` | Client/server tests |
| `FPCListener.listen()` | Server tests |
| `FPCListener.connections()` | Server tests |
| `start()` / `stop()` | All tests |
| `send()` | Test 4 (unsolicited trigger), done signals |
| `request(timeout:)` | Tests 1, 2, 3, 5 |
| `reply(to: FPCMessage)` | All server handlers |
| `incoming()` | Tests 4, 5 |

## Payload Coverage

| Payload Type | Test |
|--------------|------|
| Small inline (<64KB) | Test 1, Pair tests |
| Large OOL (100KB via shm) | Test 2 |
| Pattern-verified (64KB) | Pair Test 3 |
| Multiple file descriptors | Test 3 (3 fds) |

## UUID Verification

Every test uses runtime-generated UUIDs that:
1. Are unique per test run
2. Are logged by both client AND server
3. Must match exactly to prove real data traversal

Example output showing cross-process verification:
```
[client] → Sending request with UUID: C9435714-70E5-4DC9-9CBA-F622B9976FAB
[server] │  Payload: client-echo:C9435714-70E5-4DC9-9CBA-F622B9976FAB
[server] └→ Replying with UUID: 7F6CCB1F-7231-4E29-854B-2A9CADFB1DEA
[client] ← Received reply: server-echo:7F6CCB1F-7231-4E29-854B-2A9CADFB1DEA
```

## Verifying Real Syscalls

Use ktrace to observe actual system calls:

```bash
ktrace -i -t c .build/debug/fpc-demo pair
kdump | grep -E "socketpair|sendmsg|recvmsg"
```

Expected output:
```
socketpair(PF_LOCAL, SOCK_SEQPACKET|SOCK_CLOEXEC, ...)
sendmsg(..., MSG_EOR|MSG_NOSIGNAL)
recvmsg(..., MSG_CMSG_CLOEXEC)
```

The `MSG_EOR` flag is critical - it marks record boundaries for SEQPACKET.

## Implementation Notes

### MSG_EOR Flag
FPC uses `MSG_EOR` (End of Record) on every `sendmsg()` to preserve SEQPACKET message boundaries. Without this flag, FreeBSD may coalesce multiple rapid sends into a single recv.

### OOL (Out-of-Line) Payloads
Payloads exceeding ~64KB are automatically sent via anonymous shared memory:
1. Sender creates `shm_open()` anonymous segment
2. Payload is copied to shared memory
3. Only the shm file descriptor is passed via SCM_RIGHTS
4. Receiver mmaps and reads the payload
5. Completely transparent to API users

### Correlation IDs
- `correlationID == 0`: Unsolicited message → goes to `incoming()` stream
- `correlationID > 0` with pending request: Reply → routes to `request()` caller
- `correlationID > 0` without pending request: Incoming request → goes to `incoming()`

### Single-Claim incoming() Stream
The `incoming()` method returns an AsyncStream that can only be claimed once per endpoint. Design your message handling to use a single iteration loop.
