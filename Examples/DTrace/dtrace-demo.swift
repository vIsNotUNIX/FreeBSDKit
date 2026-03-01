/*
 * dtrace-demo - Command-line DTrace demonstration tool
 *
 * Usage:
 *   dtrace-demo scripts     - Show generated D scripts (no root needed)
 *   dtrace-demo probes      - List available probes (requires root)
 *   dtrace-demo trace       - Run a quick trace (requires root)
 *   dtrace-demo target PID  - Trace a specific PID (requires root)
 */

import DScript
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

func printScript(_ name: String, _ script: DScript) {
    print("\n\(name):")
    print("```d")
    print(script.source)
    print("```")
}

// MARK: - Commands

func showScripts() {
    printHeader("DScript - Generated D Scripts")

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

    // NEW: Result Builder API (DScript)
    printSection("DScript ResultBuilder API (Recommended)")

    print("The DScript result builder provides compile-time safety and")
    print("a declarative syntax for building D scripts.\n")

    print("Simple syscall counting:")
    print("```swift")
    print("""
    let script = DScript {
        Probe("syscall:::entry") {
            Target(.execname("nginx"))
            Count(by: "probefunc")
        }
    }
    """)
    print("```")
    print("\nGenerated D:")
    let simpleScript = DScript {
        Probe("syscall:::entry") {
            Target(.execname("nginx"))
            Count(by: "probefunc")
        }
    }
    print("```d")
    print(simpleScript.source)
    print("```\n")

    print("Latency measurement with multiple probes:")
    print("```swift")
    print("""
    let script = DScript {
        Probe("syscall::read:entry") {
            Target(.execname("postgres"))
            Timestamp()
        }
        Probe("syscall::read:return") {
            Target(.execname("postgres"))
            When("self->ts")
            Latency(by: "execname")
        }
    }
    """)
    print("```")
    print("\nGenerated D:")
    let latencyScript = DScript {
        Probe("syscall::read:entry") {
            Target(.execname("postgres"))
            Timestamp()
        }
        Probe("syscall::read:return") {
            Target(.execname("postgres"))
            When("self->ts")
            Latency(by: "execname")
        }
    }
    print("```d")
    print(latencyScript.source)
    print("```\n")

    print("Multiple actions in one probe:")
    print("```swift")
    print("""
    let script = DScript {
        Probe("syscall::open:entry") {
            Target(.execname("myapp"))
            Printf("%s[%d]: opening %s", "execname", "pid", "copyinstr(arg0)")
            Count(by: "probefunc")
            Stack(userland: true)
        }
    }
    """)
    print("```")
    print("\nGenerated D:")
    let multiActionScript = DScript {
        Probe("syscall::open:entry") {
            Target(.execname("myapp"))
            Printf("%s[%d]: opening %s", "execname", "pid", "copyinstr(arg0)")
            Count(by: "probefunc")
            Stack(userland: true)
        }
    }
    print("```d")
    print(multiActionScript.source)
    print("```\n")

    print("Available components:")
    print("  Predicates: Target(.execname(\"x\")), When(\"arg0 > 0\")")
    print("  Aggregations: Count(), Sum(), Min(), Max(), Avg(), Quantize(), Lquantize()")
    print("  Actions: Printf(), Trace(), Stack(), Action(\"raw D code\")")
    print("  Helpers: Timestamp(), Latency()")
    print()

    // Predefined scripts
    printSection("Predefined Script Templates")

    print("Available predefined scripts:\n")
    printScript("DScript.syscallCounts(for: .execname(\"node\"))",
        DScript.syscallCounts(for: .execname("node")))
    printScript("DScript.fileOpens()", DScript.fileOpens())
    printScript("DScript.cpuProfile(hz: 99)", DScript.cpuProfile(hz: 99))
    printScript("DScript.processExec()", DScript.processExec())
    printScript("DScript.ioBytes()", DScript.ioBytes())
    printScript("DScript.syscallLatency(\"read\")", DScript.syscallLatency("read"))

    // Script JSON and Validation
    printSection("Script JSON & Validation")

    print("DScript provides multiple output formats and validation:\n")

    let demoScript = DScript {
        Probe("syscall::read:entry") {
            Target(.execname("nginx"))
            Timestamp()
        }
        Probe("syscall::read:return") {
            Target(.execname("nginx"))
            When("self->ts")
            Latency(by: "execname")
        }
    }

    print("1. D Source Code (.source):")
    print("```d")
    print(demoScript.source)
    print("```\n")

    print("2. Script AST as JSON (.jsonString):")
    if let json = demoScript.jsonString {
        print(json)
    }
    print()

    print("3. Structural Validation (.validate()):")
    print("```swift")
    print("do {")
    print("    try script.validate()  // Checks structure")
    print("    print(\"Script structure is valid\")")
    print("} catch {")
    print("    print(\"Invalid: \\(error)\")")
    print("}")
    print("```")
    do {
        try demoScript.validate()
        print("Result: Script structure is valid\n")
    } catch {
        print("Result: \(error)\n")
    }

    print("4. DTrace Compilation (.compile()) - requires root:")
    print("```swift")
    print("do {")
    print("    try script.compile()  // Actually compiles with DTrace")
    print("    print(\"Script compiles successfully\")")
    print("} catch let error as DScriptError {")
    print("    print(\"Compilation failed: \\(error)\")")
    print("}")
    print("```")
    if getuid() == 0 {
        do {
            try demoScript.compile()
            print("Result: Script compiles successfully\n")
        } catch {
            print("Result: \(error)\n")
        }
    } else {
        print("Result: (skipped - requires root)\n")
    }

    print("5. Data Conversion:")
    print("  script.data              // UTF-8 Data")
    print("  script.nullTerminatedData // UTF-8 Data with null terminator")
    print("  script.write(to: path)   // Write to file")
    print()

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
    printSection("DScriptSession API Summary")

    print("Creating a session:")
    print("  var session = try DScriptSession.create()  // 4m buffers (recommended)")
    print("  var session = try DScriptSession.create(traceBufferSize: \"16m\", aggBufferSize: \"8m\")")
    print("  var session = try DScriptSession()         // Raw (need to set buffers)")
    print()
    print("Configuration:")
    print("  try session.quiet()                // Suppress default output")
    print("  try session.traceBufferSize(\"16m\") // Override trace buffer size")
    print("  try session.aggBufferSize(\"8m\")    // Override aggregation buffer size")
    print("  session.output(to: .file(\"/tmp/out\"))  // Set output destination")
    print()
    print("Adding scripts (DScript ResultBuilder API):")
    print("  session.add(script)                // Add a DScript")
    print("  session.add {                      // Add with result builder")
    print("      Probe(\"syscall:::entry\") {")
    print("          Target(.execname(\"nginx\"))")
    print("          Count(by: \"probefunc\")")
    print("      }")
    print("  }")
    print()
    print("Predefined scripts:")
    print("  session.syscallCounts(for: target)")
    print("  session.fileOpens(for: target)")
    print("  session.cpuProfile(hz: 997, for: target)")
    print("  session.ioBytes(for: target)")
    print("  session.syscallLatency(\"read\", for: target)")
    print()
    print("Execution:")
    print("  try session.enable()                // Compile and start tracing")
    print("  session.process()                     // Process data (returns .okay/.done/.error)")
    print("  session.wait()                    // Wait for data")
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
        let session = try DScriptSession.create()

        // Provider summary - dynamically discovered
        printSection("Probe Counts by Provider")

        print("Discovering providers...")
        let providers = try session.listProviders()
        print("Found \(providers.count) providers:\n")

        for provider in providers {
            let count = try session.countProbes(matching: "\(provider):::")
            print("  \(provider): \(count) probes")
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
        // Use DScript ResultBuilder API
        let script = DScript {
            Probe("profile-997") {
                Count(by: "execname")
            }
        }

        let session = try DScriptSession.start(script)

        print("Starting CPU profile (sampling at 997Hz)...")
        print("Duration: \(duration) seconds")
        print()

        // Debug: show the generated script
        print("Generated D script:")
        print(script.source)
        print()

        // Progress indicator
        for i in 1...duration {
            print("  Collecting... \(i)/\(duration)s")
            let endTime = Date().addingTimeInterval(1)
            while Date() < endTime {
                let status = session.process()
                if status == .done || status == .error {
                    break
                }
                session.wait()
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
        var session = try DScriptSession.create()
        try session.quiet()

        session.syscallCounts(for: .pid(pid))

        print("Tracing syscalls for PID \(pid) for 5 seconds...")
        print()

        try session.enable()

        for i in 1...5 {
            print("  Collecting... \(i)/5s")
            let endTime = Date().addingTimeInterval(1)
            while Date() < endTime {
                let status = session.process()
                if status == .done || status == .error {
                    break
                }
                session.wait()
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
        var session = try DScriptSession.create()
        try session.quiet()

        // Create a buffer to capture output
        let buffer = DTraceOutputBuffer()
        session.output(to: .buffer(buffer))

        // Add script using ResultBuilder API
        session.add {
            Probe("profile-97") {  // Lower frequency for demo
                Count(by: "execname")
            }
        }

        print("Capturing CPU profile to buffer for 1 second...")
        try session.enable()

        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let status = session.process()
            if status == .done || status == .error { break }
            session.wait()
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
            let workStatus = handle.poll()
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

func handlersDemo() {
    printHeader("Error and Drop Handlers Demo")

    guard getuid() == 0 else {
        print("ERROR: This demo requires root privileges.")
        print("Run with: sudo dtrace-demo handlers")
        return
    }

    do {
        let handle = try DTraceHandle.open()
        try handle.setOption("bufsize", value: "4m")
        try handle.setOption("aggsize", value: "4m")

        // Set up error handler
        print("Setting up error handler...")
        try handle.onError { error in
            print("  [ERROR] Fault \(error.fault): \(error.message)")
            return true  // Continue execution
        }

        // Set up drop handler
        print("Setting up drop handler...")
        try handle.onDrop { drop in
            print("  [DROP] \(drop.kind): \(drop.drops) records - \(drop.message)")
            return true  // Continue execution
        }

        print("Handlers registered successfully!")
        print()
        print("In a real application, these handlers would be called if:")
        print("  - An error occurs during tracing (onError)")
        print("  - Data is dropped due to buffer overflow (onDrop)")

    } catch let error as DTraceCoreError {
        print("DTrace error: \(error)")
    } catch {
        print("Error: \(error)")
    }
}

func aggregateWalkDemo() {
    printHeader("Programmatic Aggregation Walk Demo")

    guard getuid() == 0 else {
        print("ERROR: This demo requires root privileges.")
        print("Run with: sudo dtrace-demo aggwalk")
        return
    }

    do {
        let handle = try DTraceHandle.open()
        try handle.setOption("bufsize", value: "4m")
        try handle.setOption("aggsize", value: "4m")

        print("Compiling CPU profile program...")
        let program = try handle.compile("""
            profile-97
            {
                @[execname] = count();
            }
            """)

        print("Executing program...")
        try handle.exec(program)

        print("Starting trace for 1 second...")
        try handle.go()

        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let workStatus = handle.poll()
            if workStatus == .done || workStatus == .error { break }
            handle.sleep()
        }

        try handle.stop()

        printSection("Walking Aggregations Programmatically")
        print("(Raw data pointers and sizes)")
        print()

        var count = 0
        try handle.aggregateSnap()
        try handle.aggregateWalk(sorted: true) { data, size in
            count += 1
            print("  Record \(count): \(size) bytes at \(data)")
            return .next
        }

        print()
        print("Processed \(count) aggregation records")
        print()
        print("In a real application, you would parse the raw data")
        print("to extract keys and values for custom processing.")

    } catch let error as DTraceCoreError {
        print("DTrace error: \(error)")
    } catch {
        print("Error: \(error)")
    }
}

func jsonOutputDemo() {
    printHeader("JSON Structured Output Demo")

    guard getuid() == 0 else {
        print("ERROR: This demo requires root privileges.")
        print("Run with: sudo dtrace-demo json")
        return
    }

    // Part 1: Script AST as JSON (no root needed for this part)
    printSection("Part 1: Script AST as JSON")

    let script = DScript {
        Probe("profile-97") {
            Count(by: "execname")
        }
    }

    print("Script source:")
    print(script.source)
    print()

    print("Script as JSON (.jsonString):")
    if let json = script.jsonString {
        print(json)
    }
    print()

    // Part 2: DScriptSession with JSON output
    printSection("Part 2: DScriptSession JSON Output")

    do {
        var session = try DScriptSession.create()

        print("Enabling JSON output mode...")
        try session.enableJSONOutput()
        print("JSON mode enabled: \(session.isJSONOutputEnabled)")
        print()

        // Capture to buffer so we can show the JSON
        let buffer = DTraceOutputBuffer()
        session.output(to: .buffer(buffer))

        session.add {
            Probe("profile-97") {
                Count(by: "execname")
            }
        }

        print("Starting trace for 1 second...")
        try session.enable()

        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let status = session.process()
            if status == .done || status == .error { break }
            session.wait()
        }

        try session.stop()
        try session.printAggregations()

        print()
        print("JSON Output from DTrace:")
        print(buffer.contents)

        session.disableJSONOutput()

    } catch let error as DTraceCoreError {
        print("DTrace error: \(error)")
    } catch {
        print("Error: \(error)")
    }

    // Part 3: Low-level API
    printSection("Part 3: Low-Level DTraceHandle JSON")

    do {
        let handle = try DTraceHandle.open()
        try handle.setOption("bufsize", value: "4m")
        try handle.setOption("aggsize", value: "4m")

        print("Enabling structured (JSON) output on handle...")
        try handle.enableStructuredOutput()
        print("Structured output enabled: \(handle.isStructuredOutputEnabled)")
        print()

        let program = try handle.compile("""
            profile-97
            {
                @[execname] = count();
            }
            """)

        try handle.exec(program)

        print("Starting trace for 1 second...")
        try handle.go()

        let endTime = Date().addingTimeInterval(1)
        while Date() < endTime {
            let workStatus = handle.poll()
            if workStatus == .done || workStatus == .error { break }
            handle.sleep()
        }

        try handle.stop()

        print()
        print("JSON aggregation output:")
        try handle.aggregateSnap()
        try handle.aggregatePrint()

        handle.disableStructuredOutput()

    } catch let error as DTraceCoreError {
        print("DTrace error: \(error)")
    } catch {
        print("Error: \(error)")
    }
}

func showUsage() {
    print("""
    dtrace-demo - DScript API Demonstration

    Usage:
      dtrace-demo scripts     Show generated D scripts (no root needed)
      dtrace-demo probes      List available probes (requires root)
      dtrace-demo trace       Run a quick CPU profile trace (requires root)
      dtrace-demo target PID  Trace syscalls for a specific PID (requires root)
      dtrace-demo buffer      Demonstrate capturing output to buffer (requires root)
      dtrace-demo lowlevel    Demonstrate low-level DTraceHandle API (requires root)
      dtrace-demo handlers    Demonstrate error and drop handlers (requires root)
      dtrace-demo aggwalk     Demonstrate programmatic aggregation walking (requires root)
      dtrace-demo json        Demonstrate JSON structured output (requires root)
      dtrace-demo help        Show this help

    Examples:
      dtrace-demo scripts           # See what the API generates
      sudo dtrace-demo probes       # List available probes
      sudo dtrace-demo trace        # Quick CPU profile
      sudo dtrace-demo target 1234  # Trace specific process
      sudo dtrace-demo buffer       # Capture to memory buffer
      sudo dtrace-demo lowlevel     # Low-level API demo
      sudo dtrace-demo handlers     # Error/drop handler callbacks
      sudo dtrace-demo aggwalk      # Walk aggregations programmatically
      sudo dtrace-demo json         # Get JSON output from DTrace
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
    case "handlers":
        handlersDemo()
    case "aggwalk":
        aggregateWalkDemo()
    case "json":
        jsonOutputDemo()
    case "help", "-h", "--help":
        showUsage()
    default:
        print("Unknown command: \(args.first!)")
        showUsage()
    }
}
