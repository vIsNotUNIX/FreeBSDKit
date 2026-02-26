import FPC
import Capabilities
import Descriptors

// FPC Core Types:
//
// FPCListener - Accepts incoming connections
// FPCClient   - Connects to a server
// FPCEndpoint - A connected endpoint (client or accepted connection)
// FPCMessage  - A message with optional descriptors

// FPC uses SEQPACKET sockets which:
// - Preserve message boundaries
// - Are connection-oriented
// - Support descriptor passing
