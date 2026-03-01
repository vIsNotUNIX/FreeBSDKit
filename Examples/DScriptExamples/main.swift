/*
 * DScript API Examples
 *
 * This file demonstrates the DScript API at various complexity levels.
 * Run with: sudo .build/debug/dscript-examples
 */

import DScript
import Foundation

// MARK: - Example 1: Minimal (Print D source only)

func example1_minimal() {
    print("=" .repeating(60))
    print("EXAMPLE 1: Minimal - Count syscalls")
    print("=" .repeating(60))

    let script = DScript {
        Probe("syscall:::entry") {
            Count(by: "probefunc")
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 2: Simple - With target filtering

func example2_withTarget() {
    print("=" .repeating(60))
    print("EXAMPLE 2: With Target Filter")
    print("=" .repeating(60))

    // Filter to a specific process
    let script = DScript {
        Probe("syscall:::entry") {
            Target(.execname("sh"))
            Count(by: "probefunc")
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 3: With BEGIN/END clauses

func example3_beginEnd() {
    print("=" .repeating(60))
    print("EXAMPLE 3: BEGIN/END Clauses")
    print("=" .repeating(60))

    let script = DScript {
        BEGIN {
            Printf("Starting syscall trace...")
        }

        Probe("syscall:::entry") {
            Count(by: "probefunc", into: "calls")
        }

        END {
            Printf("Trace complete. Results:")
            Printa("calls")
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 4: Timed execution with Tick

func example4_timedWithTick() {
    print("=" .repeating(60))
    print("EXAMPLE 4: Timed Execution (5 seconds)")
    print("=" .repeating(60))

    let script = DScript {
        Probe("syscall:::entry") {
            Count(by: "probefunc", into: "calls")
        }

        // Print every second
        Tick(1, .seconds) {
            Printf("--- Partial results ---")
            Printa("calls")
            Clear("calls")
        }

        // Exit after 5 seconds
        Tick(5, .seconds) {
            Exit(0)
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 5: Latency measurement

func example5_latency() {
    print("=" .repeating(60))
    print("EXAMPLE 5: Syscall Latency Measurement")
    print("=" .repeating(60))

    let script = DScript {
        // Record timestamp at entry
        Probe("syscall::read:entry") {
            Timestamp()
        }

        // Calculate latency at return
        Probe("syscall::read:return") {
            When("self->ts")
            Latency(by: "execname")
        }

        // Exit after 3 seconds
        Tick(3, .seconds) {
            Exit(0)
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 6: Multiple aggregations

func example6_multipleAggregations() {
    print("=" .repeating(60))
    print("EXAMPLE 6: Multiple Aggregations")
    print("=" .repeating(60))

    let script = DScript {
        Probe("syscall::read:return") {
            When("arg0 > 0")
            Count(by: "execname", into: "reads")
            Sum("arg0", by: "execname", into: "bytes")
            Max("arg0", by: "execname", into: "maxsize")
        }

        Probe("syscall::write:return") {
            When("arg0 > 0")
            Count(by: "execname", into: "writes")
            Sum("arg0", by: "execname", into: "wbytes")
        }

        END {
            Printf("Read counts:")
            Printa("reads")
            Printf("\\nBytes read:")
            Printa("bytes")
            Printf("\\nMax read size:")
            Printa("maxsize")
            Printf("\\nWrite counts:")
            Printa("writes")
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 7: File opens with path

func example7_fileOpens() {
    print("=" .repeating(60))
    print("EXAMPLE 7: File Opens Tracing")
    print("=" .repeating(60))

    let script = DScript {
        Probe("syscall::open:entry") {
            Printf("%s[%d] opening: %s", "execname", "pid", "copyinstr(arg0)")
        }

        Probe("syscall::openat:entry") {
            Printf("%s[%d] openat: %s", "execname", "pid", "copyinstr(arg1)")
        }

        Tick(5, .seconds) {
            Exit(0)
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 8: Complex - Combined targets

func example8_combinedTargets() {
    print("=" .repeating(60))
    print("EXAMPLE 8: Combined Target Filters")
    print("=" .repeating(60))

    // Trace nginx OR httpd, but only if running as www user (uid 80)
    let webServers = DTraceTarget.execname("nginx") || .execname("httpd")
    let asWww = webServers && .uid(80)

    let script = DScript {
        Probe("syscall:::entry") {
            Target(asWww)
            Count(by: ["execname", "probefunc"])
        }

        Tick(5, .seconds) {
            Exit(0)
        }
    }

    print("Target predicate: \(asWww)")
    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 9: CPU Profiling

func example9_cpuProfile() {
    print("=" .repeating(60))
    print("EXAMPLE 9: CPU Profiling (997 Hz sampling)")
    print("=" .repeating(60))

    let script = DScript {
        Profile(hz: 997) {
            When("arg1")  // User-space samples only (arg1 = user PC)
            Count(by: "execname", into: "samples")
        }

        Tick(3, .seconds) {
            Trunc("samples", 10)
            Printa("samples")
            Exit(0)
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 10: Variables and state

func example10_variables() {
    print("=" .repeating(60))
    print("EXAMPLE 10: Variables and State Tracking")
    print("=" .repeating(60))

    let script = DScript {
        BEGIN {
            Assign(.global("total_reads"), to: "0")
            Assign(.global("total_writes"), to: "0")
        }

        Probe("syscall::read:entry") {
            Assign(.thread("read_start"), to: "timestamp")
        }

        Probe("syscall::read:return") {
            When("self->read_start && arg0 > 0")
            Assign(.global("total_reads"), to: "total_reads + 1")
            Quantize("timestamp - self->read_start", by: "execname", into: "read_lat")
            Assign(.thread("read_start"), to: "0")
        }

        Probe("syscall::write:return") {
            When("arg0 > 0")
            Assign(.global("total_writes"), to: "total_writes + 1")
        }

        Tick(5, .seconds) {
            Printf("Total reads: %d, Total writes: %d", "total_reads", "total_writes")
            Exit(0)
        }

        END {
            Printf("Read latency distribution:")
            Printa("read_lat")
        }
    }

    print("Generated D code:")
    print(script.source)
    print()
}

// MARK: - Example 11: Predefined scripts

func example11_predefined() {
    print("=" .repeating(60))
    print("EXAMPLE 11: Predefined Scripts")
    print("=" .repeating(60))

    print("syscallCounts():")
    print(DScript.syscallCounts().source)
    print()

    print("syscallCounts(for: .execname(\"nginx\")):")
    print(DScript.syscallCounts(for: .execname("nginx")).source)
    print()

    print("fileOpens():")
    print(DScript.fileOpens().source)
    print()

    print("cpuProfile(hz: 99):")
    print(DScript.cpuProfile(hz: 99).source)
    print()

    print("syscallLatency(\"read\"):")
    print(DScript.syscallLatency("read").source)
    print()
}

// MARK: - Example 12: JSON representation

func example12_json() {
    print("=" .repeating(60))
    print("EXAMPLE 12: JSON Representation")
    print("=" .repeating(60))

    let script = DScript {
        BEGIN {
            Printf("Start")
        }
        Probe("syscall:::entry") {
            Target(.execname("sh"))
            Count(by: "probefunc")
        }
    }

    print("JSON representation:")
    if let json = script.jsonString {
        print(json)
    }
    print()
}

// MARK: - Example 13: Actually run a script

func example13_runScript() {
    print("=" .repeating(60))
    print("EXAMPLE 13: Actually Running a Script (3 seconds)")
    print("=" .repeating(60))

    do {
        // Simple 3-second syscall count using the new DScript API
        try DScript.run(for: 3) {
            Probe("syscall:::entry") {
                Count(by: "probefunc", into: "calls")
            }

            END {
                Trunc("calls", 15)
                Printa("calls")
            }
        }
    } catch {
        print("Error running script: \(error)")
        print("(This requires root privileges)")
    }
    print()
}

// MARK: - Main

extension String {
    func repeating(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

print("""
╔══════════════════════════════════════════════════════════════╗
║                   DScript API Examples                       ║
║                                                              ║
║  This demonstrates the DScript result builder API for        ║
║  constructing type-safe DTrace scripts in Swift.             ║
╚══════════════════════════════════════════════════════════════╝

""")

// Run all print-only examples
example1_minimal()
example2_withTarget()
example3_beginEnd()
example4_timedWithTick()
example5_latency()
example6_multipleAggregations()
example7_fileOpens()
example8_combinedTargets()
example9_cpuProfile()
example10_variables()
example11_predefined()
example12_json()

// Ask before running the live trace
print("=" .repeating(60))
print("Run live trace? (requires root)")
print("=" .repeating(60))

// Check if running as root
if geteuid() == 0 {
    print("Running as root - executing live trace...")
    example13_runScript()
} else {
    print("Not running as root - skipping live trace.")
    print("To run: sudo .build/debug/dscript-examples")
}

print("""

╔══════════════════════════════════════════════════════════════╗
║                      Examples Complete                       ║
╚══════════════════════════════════════════════════════════════╝
""")
