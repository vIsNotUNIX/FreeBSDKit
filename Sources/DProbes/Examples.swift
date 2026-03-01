/*
 * DProbes - Usage Examples
 *
 * Copyright (c) 2026 Kory Heard
 * SPDX-License-Identifier: BSD-2-Clause
 */

// MARK: - Example 1: Basic Web Server Probes

/*
 * Provider definition for a web server:
 *
 *     #DTraceProvider(
 *         name: "webserver",
 *         stability: .evolving,
 *
 *         probes: {
 *             #probe(
 *                 name: "request_start",
 *                 args: (
 *                     path: String,
 *                     method: Int32,
 *                     clientIP: String,
 *                     requestID: UInt64
 *                 ),
 *                 docs: "Fires when request processing begins."
 *             )
 *
 *             #probe(
 *                 name: "request_done",
 *                 args: (
 *                     path: String,
 *                     status: Int32,
 *                     responseSize: Int64,
 *                     latencyNs: UInt64,
 *                     requestID: UInt64
 *                 ),
 *                 docs: "Fires when request processing completes."
 *             )
 *
 *             #probe(
 *                 name: "error",
 *                 args: (
 *                     code: Int32,
 *                     message: String,
 *                     requestID: UInt64
 *                 )
 *             )
 *         }
 *     )
 *
 * Usage in request handler:
 *
 *     func handleRequest(_ req: Request) async throws -> Response {
 *         let requestID = RequestID.generate()
 *         let startTime = ContinuousClock.now
 *
 *         #probe(webserver.request_start,
 *             path: req.url.path,
 *             method: req.method.rawValue,
 *             clientIP: req.remoteAddress,
 *             requestID: requestID
 *         )
 *
 *         do {
 *             let response = try await process(req)
 *             let latency = ContinuousClock.now - startTime
 *
 *             #probe(webserver.request_done,
 *                 path: req.url.path,
 *                 status: Int32(response.status.code),
 *                 responseSize: Int64(response.body?.count ?? 0),
 *                 latencyNs: latency.nanoseconds,
 *                 requestID: requestID
 *             )
 *
 *             return response
 *         } catch {
 *             #probe(webserver.error,
 *                 code: (error as? AppError)?.code ?? -1,
 *                 message: error.localizedDescription,
 *                 requestID: requestID
 *             )
 *             throw error
 *         }
 *     }
 *
 * DTrace one-liners to analyze:
 *
 *     # Count requests by path
 *     dtrace -n 'webserver:::request_start { @[copyinstr(arg0)] = count(); }'
 *
 *     # Latency histogram by path
 *     dtrace -n 'webserver:::request_done { @[copyinstr(arg0)] = quantize(arg3/1000000); }'
 *
 *     # Requests per second
 *     dtrace -n 'webserver:::request_start { @ = count(); } tick-1s { printa(@); clear(@); }'
 *
 *     # Error rate
 *     dtrace -n 'webserver:::error { @[arg0] = count(); }'
 */

// MARK: - Example 2: Database Layer Probes

/*
 * Provider for database operations:
 *
 *     #DTraceProvider(
 *         name: "mydb",
 *         stability: .evolving,
 *
 *         probes: {
 *             #probe(
 *                 name: "query_start",
 *                 args: (
 *                     query: String,
 *                     database: String,
 *                     queryID: UInt64
 *                 )
 *             )
 *
 *             #probe(
 *                 name: "query_done",
 *                 args: (
 *                     queryID: UInt64,
 *                     rowCount: Int32,
 *                     latencyNs: UInt64
 *                 )
 *             )
 *
 *             #probe(
 *                 name: "connection_open",
 *                 args: (
 *                     host: String,
 *                     port: UInt16,
 *                     database: String
 *                 )
 *             )
 *
 *             #probe(
 *                 name: "connection_close",
 *                 args: (
 *                     host: String,
 *                     connectionID: UInt64,
 *                     durationMs: UInt64
 *                 )
 *             )
 *         }
 *     )
 *
 * Usage:
 *
 *     func execute(_ sql: String, on db: Database) throws -> [Row] {
 *         let queryID = QueryID.generate()
 *         let start = ContinuousClock.now
 *
 *         #probe(mydb.query_start,
 *             query: sql,
 *             database: db.name,
 *             queryID: queryID
 *         )
 *
 *         let rows = try db.execute(sql)
 *         let latency = ContinuousClock.now - start
 *
 *         #probe(mydb.query_done,
 *             queryID: queryID,
 *             rowCount: Int32(rows.count),
 *             latencyNs: latency.nanoseconds
 *         )
 *
 *         return rows
 *     }
 *
 * DTrace analysis:
 *
 *     # Slow queries (> 100ms)
 *     dtrace -n 'mydb:::query_done /arg2 > 100000000/ {
 *         printf("Slow query: %d ms\n", arg2/1000000);
 *     }'
 *
 *     # Query latency distribution
 *     dtrace -n 'mydb:::query_done { @["latency (ms)"] = quantize(arg2/1000000); }'
 */

// MARK: - Example 3: Cache Layer Probes

/*
 * Simple cache probes:
 *
 *     #DTraceProvider(
 *         name: "cache",
 *
 *         probes: {
 *             #probe(
 *                 name: "get",
 *                 args: (
 *                     key: String,
 *                     hit: Int32,       // 1 = hit, 0 = miss
 *                     size: Int64       // bytes, 0 if miss
 *                 )
 *             )
 *
 *             #probe(
 *                 name: "set",
 *                 args: (
 *                     key: String,
 *                     size: Int64,
 *                     ttlSeconds: Int32
 *                 )
 *             )
 *
 *             #probe(
 *                 name: "evict",
 *                 args: (
 *                     key: String,
 *                     reason: Int32     // 1=expired, 2=capacity, 3=explicit
 *                 )
 *             )
 *         }
 *     )
 *
 * Usage:
 *
 *     func get(_ key: String) -> Data? {
 *         if let data = storage[key] {
 *             #probe(cache.get, key: key, hit: 1, size: Int64(data.count))
 *             return data
 *         } else {
 *             #probe(cache.get, key: key, hit: 0, size: 0)
 *             return nil
 *         }
 *     }
 *
 * DTrace analysis:
 *
 *     # Hit rate
 *     dtrace -n 'cache:::get { @[arg1 ? "hit" : "miss"] = count(); }'
 *
 *     # Hot keys
 *     dtrace -n 'cache:::get { @[copyinstr(arg0)] = count(); }'
 */

// MARK: - Example 4: Custom Type Translation

/*
 * Custom types can conform to DTraceConvertible:
 *
 *     enum HTTPMethod: Int32, DTraceConvertible {
 *         case get = 1
 *         case post = 2
 *         case put = 3
 *         case delete = 4
 *
 *         var dtraceValue: Int32 { rawValue }
 *     }
 *
 *     struct RequestID: DTraceConvertible {
 *         let value: UInt64
 *
 *         var dtraceValue: UInt64 { value }
 *     }
 *
 *     enum CacheEvictionReason: Int32, DTraceConvertible {
 *         case expired = 1
 *         case capacity = 2
 *         case explicit = 3
 *
 *         var dtraceValue: Int32 { rawValue }
 *     }
 *
 * Now these can be used directly in probes:
 *
 *     #probe(webserver.request_start,
 *         path: req.path,
 *         method: req.method,        // HTTPMethod → Int32
 *         requestID: req.id          // RequestID → UInt64
 *     )
 */

// MARK: - Example 5: Conditional Probing (Manual IS-ENABLED)

/*
 * For very expensive argument computation, you can manually check IS-ENABLED:
 *
 *     // The macro generates an isEnabled check:
 *     if #probeEnabled(myapp.debug) {
 *         // Only compute if someone is tracing
 *         let expensiveContext = buildDebugContext()
 *         let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
 *
 *         #probe(myapp.debug,
 *             context: expensiveContext,
 *             stack: stackTrace
 *         )
 *     }
 *
 * However, this is rarely needed because #probe already uses IS-ENABLED
 * internally and only evaluates arguments when tracing is active.
 */

// MARK: - Example 6: Cross-Module Providers

/*
 * A library can define a provider that applications extend:
 *
 * In NetworkingLib:
 *
 *     #DTraceProvider(
 *         name: "networking",
 *         stability: .stable,
 *         extensible: true,          // Allow extensions
 *
 *         probes: {
 *             #probe(name: "connect", args: (host: String, port: UInt16))
 *             #probe(name: "disconnect", args: (host: String, reason: Int32))
 *         }
 *     )
 *
 * In application:
 *
 *     #extendProvider("networking",
 *         probes: {
 *             #probe(name: "custom_metric", args: (value: Int64))
 *         }
 *     )
 *
 * All probes appear under the same provider:
 *     networking:::connect
 *     networking:::disconnect
 *     networking:::custom_metric
 */

// MARK: - Generated D File Example

/*
 * For the webserver provider, the macro generates:
 *
 * --- webserver_provider.d ---
 *
 *     provider webserver {
 *         / * Fires when request processing begins. * /
 *         probe request__start(
 *             char *path,        / * arg0: Request URL path * /
 *             int32_t method,    / * arg1: HTTP method * /
 *             char *clientIP,    / * arg2: Client IP address * /
 *             uint64_t requestID / * arg3: Unique request ID * /
 *         );
 *
 *         / * Fires when request processing completes. * /
 *         probe request__done(
 *             char *path,
 *             int32_t status,
 *             int64_t responseSize,
 *             uint64_t latencyNs,
 *             uint64_t requestID
 *         );
 *
 *         probe error(
 *             int32_t code,
 *             char *message,
 *             uint64_t requestID
 *         );
 *     };
 *
 *     #pragma D attributes Evolving/Evolving/Common provider webserver provider
 *     #pragma D attributes Evolving/Evolving/Common provider webserver module
 *     #pragma D attributes Evolving/Evolving/Common provider webserver function
 *     #pragma D attributes Evolving/Evolving/Common provider webserver name
 *     #pragma D attributes Evolving/Evolving/Common provider webserver args
 */
