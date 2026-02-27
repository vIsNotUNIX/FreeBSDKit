/*
 * dtrace-demo - Command-line DTrace demonstration tool
 *
 * Usage:
 *   dtrace-demo scripts     - Show generated D scripts (no root needed)
 *   dtrace-demo probes      - List available probes (requires root)
 *   dtrace-demo trace       - Run a quick trace (requires root)
 *   dtrace-demo target PID  - Trace a specific PID (requires root)
 */

import DTraceBuilder
import Foundation

// MARK: - Helpers

func printHeader(_ title: String) {
    print()
    print(String(repeating: "=", count: 60))
    print(title)
    print(String(repeating: "=", count: 60))
    print()
}

func printSection(_ title: String) {
    print()
    print(String(repeating: "-", count: 40))
    print(title)
    print(String(repeating: "-", count: 40))
}

func printScript(_ name: String, _ script: DTraceScript) {
    print("\n\(name):")
    print("```d")
    print(script.build())
    print("```")
}

// MARK: - Commands

func showScripts() {
    printHeader("DTraceBuilder - Generated D Scripts")

    // Target examples
    printSection("DTraceTarget Examples")

    let targets: [(String, DTraceTarget)] = [
        ("Process by PID", .pid(1234)),
        ("Process by name", .execname("nginx")),
        ("Name contains", .processNameContains("http")),
        ("User ID", .uid(0)),
        ("Group ID", .gid(0)),
        ("Jail ID", .jail(1)),
        ("Combined (AND)", .execname("postgres") && .uid(70)),
        ("Combined (OR)", .execname("nginx") || .execname("apache")),
        ("Negated", !DTraceTarget.uid(0)),
        ("Complex", (.execname("nginx") || .execname("apache")) && !.uid(0)),
    ]

    for (name, target) in targets {
        print("\(name):")
        print("  Target: \(target)")
        print("  Predicate: \(target.predicate)")
        print()
    }

    // Script examples
    printSection("DTraceScript Examples")

    printScript("Syscall counting",
        DTraceScript("syscall:::entry")
            .targeting(.execname("node"))
            .count(by: "probefunc")
    )

    printScript("File opens with path",
        DTraceScript("syscall::open*:entry")
            .printf("%s[%d]: %s", "execname", "pid", "copyinstr(arg0)")
    )

    printScript("Read latency histogram",
        DTraceScript("syscall::read:entry")
            .targeting(.execname("postgres"))
            .action("self->ts = timestamp;")
            .probe("syscall::read:return")
            .targeting(.execname("postgres"))
            .when("self->ts")
            .action("@[execname] = quantize(timestamp - self->ts); self->ts = 0;")
    )

    printScript("Bytes written per process",
        DTraceScript("syscall::write:return")
            .when("arg0 > 0")
            .sum("arg0", by: "execname")
    )

    printScript("Kernel stack traces",
        DTraceScript("fbt::malloc:entry")
            .targeting(.execname("myapp"))
            .stack()
    )

    printScript("User stack traces",
        DTraceScript("pid$target:::entry")
            .stack(userland: true)
    )

    // Predefined scripts
    printSection("Predefined Script Templates")

    printScript("syscallCounts()", DTraceScript.syscallCounts())
    printScript("syscallCounts(for: .execname(\"node\"))", DTraceScript.syscallCounts(for: .execname("node")))
    printScript("fileOpens()", DTraceScript.fileOpens())
    printScript("cpuProfile(hz: 99)", DTraceScript.cpuProfile(hz: 99))
    printScript("processExec()", DTraceScript.processExec())
    printScript("ioBytes()", DTraceScript.ioBytes())
    printScript("syscallLatency(\"read\")", DTraceScript.syscallLatency("read"))

    // Aggregation examples
    printSection("Aggregation Helpers")

    printScript("count()",
        DTraceScript("syscall:::entry").count())

    printScript("count(by: \"execname\")",
        DTraceScript("syscall:::entry").count(by: "execname"))

    printScript("sum()",
        DTraceScript("syscall::read:return").when("arg0 > 0").sum("arg0"))

    printScript("min()",
        DTraceScript("syscall::read:return").when("arg0 > 0").min("arg0"))

    printScript("max()",
        DTraceScript("syscall::read:return").when("arg0 > 0").max("arg0"))

    printScript("avg()",
        DTraceScript("syscall::read:return").when("arg0 > 0").avg("arg0"))

    printScript("quantize()",
        DTraceScript("syscall::read:return").when("arg0 > 0").quantize("arg0"))

    printScript("lquantize(0, 1000, 100)",
        DTraceScript("syscall::read:return")
            .when("arg0 > 0")
            .lquantize("arg0", low: 0, high: 1000, step: 100))

    // Output destinations
    printSection("DTraceOutput Destinations")

    print("Available output destinations for session.output(to:):")
    print("  .stdout              - Standard output (default)")
    print("  .stderr              - Standard error")
    print("  .null                - Discard output")
    print("  .file(\"/path\")       - Write to file")
    print("  .buffer(buffer)      - Capture to DTraceOutputBuffer")
    print("  .fileDescriptor(fd)  - Write to file descriptor")
    print()
    print("Example - capturing to buffer:")
    print("  let buffer = DTraceOutputBuffer()")
    print("  session.output(to: .buffer(buffer))")
    print("  // ... run trace ...")
    print("  let output = buffer.contents  // Get captured output")

    // Type info
    printSection("DTraceCore Types")

    print("DTraceCore.version: \(DTraceCore.version)")
    print()

    let probe = DTraceProbeDescription(
        id: 12345,
        provider: "syscall",
        module: "freebsd",
        function: "open",
        name: "entry"
    )
    print("DTraceProbeDescription:")
    print("  \(probe.debugDescription)")
    print("  fullName: \(probe.fullName)")
    print()

    print("DTraceWorkStatus: .error, .okay, .done")
    print("DTraceStatus: .none, .okay, .exited, .filled, .stopped")
    print()

    print("DTraceOpenFlags: .noDevice, .noSystem, .lp64, .ilp32")
    print("DTraceCompileFlags: .verbose, .allowEmpty, .allowZeroMatches, .probeSpec, .noLibs")

    // Session API summary
    printSection("DTraceSession API Summary")

    print("Creating a session:")
    print("  var session = try DTraceSession.create()  // 4m buffers (recommended)")
    print("  var session = try DTraceSession.create(traceBufferSize: \"16m\", aggBufferSize: \"8m\")")
    print("  var session = try DTraceSession()         // Raw (need to set buffers)")
    print()
    print("Configuration:")
    print("  session.quiet()                    // Suppress default output")
    print("  session.traceBufferSize(\"16m\")     // Override trace buffer size")
    print("  session.aggBufferSize(\"8m\")        // Override aggregation buffer size")
    print("  session.output(to: .file(\"/tmp/out\"))  // Set output destination")
    print()
    print("Building traces (fluent API):")
    print("  session.trace(\"syscall:::entry\")   // Start a probe clause")
    print("  session.targeting(.execname(\"nginx\"))")
    print("  session.when(\"arg0 > 0\")           // Add predicate")
    print("  session.counting(by: .function)   // Add aggregation")
    print()
    print("Predefined traces:")
    print("  session.syscallCounts(for: target)")
    print("  session.fileOpens(for: target)")
    print("  session.cpuProfile(hz: 997, for: target)")
    print("  session.ioBytes(for: target)")
    print("  session.syscallLatency(\"read\", for: target)")
    print()
    print("Execution:")
    print("  try session.start()                // Compile and start tracing")
    print("  session.work()                     // Process data (returns .okay/.done/.error)")
    print("  session.sleep()                    // Wait for data")
    print("  try session.stop()                 // Stop tracing")
    print()
    print("Aggregations:")
    print("  try session.printAggregations()    // Print to configured output")
    print("  try session.snapshotAggregations() // Take snapshot")
    print("  session.clearAggregations()        // Clear data")
    print()
    print("Probe discovery:")
    print("  try session.listProbes(matching: \"syscall:::\")")
    print("  try session.countProbes(matching: \"fbt:::\")")
}

func listProbes() {
    printHeader("Available DTrace Probes")

    guard getuid() == 0 else {
        print("ERROR: Listing probes requires root privileges.")
        print("Run with: sudo dtrace-demo probes")
        return
    }

    do {
        let session = try DTraceSession.create()

        // Provider summary
        printSection("Probe Counts by Provider")

        // FreeBSD DTrace providers (ordered by typical usage)
        let providers = [
            // Core tracing
            "syscall",      // System call entry/return
            "fbt",          // Function boundary tracing (kernel)
            "profile",      // Profiling (timer-based sampling)
            "dtrace",       // Meta provider (BEGIN/END/ERROR)

            // Process/scheduling
            "proc",         // Process lifecycle events
            "sched",        // Scheduler events

            // I/O and networking
            "io",           // Block I/O
            "ip", "tcp", "udp", "sctp",  // Network protocols
            "vfs",          // VFS operations

            // Specialized
            "lockstat",     // Lock statistics
            "sdt",          // Static defined tracing (kernel markers)
            "kinst",        // Kernel instruction tracing

            // Userland (require target process)
            "fasttrap",     // Userland tracing
            "pid",          // Per-process function tracing
            "usdt",         // Userland SDT
        ]
        for provider in providers {
            let count = try session.countProbes(matching: "\(provider):::")
            if count > 0 {
                print("  \(provider): \(count) probes")
            }
        }

        // Sample probes
        printSection("Sample syscall:::entry Probes")

        let syscallProbes = try session.listProbes(matching: "syscall:::entry")
        for probe in syscallProbes.prefix(20) {
            print("  \(probe.fullName)")
        }
        print("  ... and \(syscallProbes.count - 20) more")

    } catch {
        print("Error: \(error)")
    }
}

func runTrace(duration: Int = 3) {
    printHeader("Live DTrace Session (\(duration) seconds)")

    guard getuid() == 0 else {
        print("ERROR: Tracing requires root privileges.")
        print("Run with: sudo dtrace-demo trace")
        return
    }

    do {
        var session = try DTraceSession.create()  // Use factory with proper defaults

        // Use profile provider which has fewer probes and lower overhead
        session.trace("profile-997")
        session.counting(by: .execname)

        print("Starting CPU profile (sampling at 997Hz)...")
        print("Duration: \(duration) seconds")
        print()

        // Debug: show the generated script
        print("Generated D script:")
        print(session.buildSource())
        print()

        try session.start()

        // Progress indicator
        for i in 1...duration {
            print("  Collecting... \(i)/\(duration)s")
            let endTime = Date().addingTimeInterval(1)
            while Date() < endTime {
                let status = session.work()
                if status == .done || status == .error {
                    break
                }
                session.sleep()
            }
        }

        try session.stop()

        printSection("CPU Usage by Process")
        try session.printAggregations()

    } catch {
        print("Error: \(error)")
    }
}

func traceProcess(_ pidStr: String) {
    guard let pid = Int32(pidStr) else {
        print("ERROR: Invalid PID: \(pidStr)")
        return
    }

    printHeader("Tracing PID \(pid)")

    guard getuid() == 0 else {
        print("ERROR: Tracing requires root privileges.")
        print("Run with: sudo dtrace-demo target \(pid)")
        return
    }

    do {
        var session = try DTraceSession.create()
        try session.quiet()

        session.syscallCounts(for: .pid(pid))

        print("Tracing syscalls for PID \(pid) for 5 seconds...")
        print()

        try session.start()

        for i in 1...5 {
            print("  Collecting... \(i)/5s")
            let endTime = Date().addingTimeInterval(1)
            while Date() < endTime {
                let status = session.work()
                if status == .done || status == .error {
                    break
                }
                session.sleep()
            }
        }

        try session.stop()

        printSection("Syscall Counts for PID \(pid)")
        try session.printAggregations()

    } catch {
        print("Error: \(error)")
    }
}

func captureToBuffer() {
    printHeader("Capturing DTrace Output to Buffer")

    guard getuid() == 0 else {
        print("ERROR: Tracing requires root privileges.")
        print("Run with: sudo dtrace-demo buffer")
        return
    }

    do {
        var session = try DTraceSession.create()
        try session.quiet()

        // Create a buffer to capture output
        let buffer = DTraceOutputBuffer()
        session.output(to: .buffer(buffer))

        session.trace("profile-97")  // Lower frequency for demo
        session.counting(by: .execname)

        print("Capturing CPU profile to buffer for 1 second...")
        try session.start()

        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let status = session.work()
            if status == .done || status == .error { break }
            session.sleep()
        }

        try session.stop()
        try session.printAggregations(to: .buffer(buffer))

        printSection("Captured Buffer Contents")
        let contents = buffer.contents
        if contents.isEmpty {
            print("(Buffer is empty - no output captured)")
        } else {
            print(contents)
        }

        print()
        print("Buffer length: \(contents.count) characters")
        print()
        print("This demonstrates programmatic capture of DTrace output")
        print("for processing in your application.")

    } catch {
        print("Error: \(error)")
    }
}

func lowLevelDemo() {
    printHeader("Low-Level DTraceHandle API")

    guard getuid() == 0 else {
        print("ERROR: This demo requires root privileges.")
        print("Run with: sudo dtrace-demo lowlevel")
        return
    }

    do {
        print("Opening DTrace handle...")
        let handle = try DTraceHandle.open()
        print("  Handle opened successfully")
        print("  Last error: \(handle.lastError)")
        print()

        print("Setting options...")
        try handle.setOption("bufsize", value: "4m")
        try handle.setOption("aggsize", value: "4m")
        let bufsize = try handle.getOption("bufsize")
        print("  bufsize = \(bufsize) bytes")
        print()

        print("Compiling D program...")
        let source = """
            profile-97
            {
                @[execname] = count();
            }
            """
        let program = try handle.compile(source)
        print("  Program compiled successfully")
        print()

        print("Executing program...")
        let info = try handle.exec(program)
        print("  Aggregates: \(info.aggregates)")
        print("  Record generators: \(info.recordGenerators)")
        print("  Probe matches: \(info.matches)")
        print("  Speculations: \(info.speculations)")
        print()

        print("Starting trace...")
        try handle.go()
        print("  Status: \(handle.status)")
        print()

        print("Collecting for 1 second...")
        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let workStatus = handle.work()
            if workStatus == .done || workStatus == .error { break }
            handle.sleep()
        }

        print("Stopping...")
        try handle.stop()
        print()

        printSection("Results (Low-Level API)")
        try handle.aggregateSnap()
        try handle.aggregatePrint()

        print()
        print("Handle will be closed automatically when it goes out of scope.")

    } catch let error as DTraceCoreError {
        print("DTrace error: \(error)")
    } catch {
        print("Error: \(error)")
    }
}

func showUsage() {
    print("""
    dtrace-demo - DTraceBuilder API Demonstration

    Usage:
      dtrace-demo scripts     Show generated D scripts (no root needed)
      dtrace-demo probes      List available probes (requires root)
      dtrace-demo trace       Run a quick CPU profile trace (requires root)
      dtrace-demo target PID  Trace syscalls for a specific PID (requires root)
      dtrace-demo buffer      Demonstrate capturing output to buffer (requires root)
      dtrace-demo lowlevel    Demonstrate low-level DTraceHandle API (requires root)
      dtrace-demo help        Show this help

    Examples:
      dtrace-demo scripts           # See what the API generates
      sudo dtrace-demo probes       # List available probes
      sudo dtrace-demo trace        # Quick CPU profile
      sudo dtrace-demo target 1234  # Trace specific process
      sudo dtrace-demo buffer       # Capture to memory buffer
      sudo dtrace-demo lowlevel     # Low-level API demo
    """)
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

if args.isEmpty {
    showUsage()
} else {
    switch args.first! {
    case "scripts":
        showScripts()
    case "probes":
        listProbes()
    case "trace":
        runTrace()
    case "target":
        if args.count > 1 {
            traceProcess(args.dropFirst().first!)
        } else {
            print("ERROR: Missing PID argument")
            print("Usage: dtrace-demo target PID")
        }
    case "buffer":
        captureToBuffer()
    case "lowlevel":
        lowLevelDemo()
    case "help", "-h", "--help":
        showUsage()
    default:
        print("Unknown command: \(args.first!)")
        showUsage()
    }
}
