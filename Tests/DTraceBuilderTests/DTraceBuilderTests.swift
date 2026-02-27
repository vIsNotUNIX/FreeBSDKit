/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
@testable import DTraceBuilder

@Suite("DTraceTarget Tests")
struct DTraceTargetTests {

    @Test("Target for PID")
    func testPidTarget() {
        let target = DTraceTarget.pid(1234)
        #expect(target.predicate == "pid == 1234")
        #expect(target.description == "/pid == 1234/")
    }

    @Test("Target for execname")
    func testExecnameTarget() {
        let target = DTraceTarget.execname("nginx")
        #expect(target.predicate == "execname == \"nginx\"")
    }

    @Test("Target for process name contains")
    func testProcessNameContains() {
        let target = DTraceTarget.processNameContains("http")
        #expect(target.predicate == "strstr(execname, \"http\") != NULL")
    }

    @Test("Target for UID")
    func testUidTarget() {
        let target = DTraceTarget.uid(1000)
        #expect(target.predicate == "uid == 1000")
    }

    @Test("Target for GID")
    func testGidTarget() {
        let target = DTraceTarget.gid(100)
        #expect(target.predicate == "gid == 100")
    }

    @Test("Target for jail")
    func testJailTarget() {
        let target = DTraceTarget.jail(5)
        #expect(target.predicate == "jid == 5")
    }

    @Test("All target has empty predicate")
    func testAllTarget() {
        let target = DTraceTarget.all
        #expect(target.predicate.isEmpty)
        #expect(target.description == "(all)")
    }

    @Test("Current process target")
    func testCurrentProcessTarget() {
        let target = DTraceTarget.currentProcess
        #expect(target.predicate.contains("pid == "))
    }

    @Test("Combining targets with AND")
    func testAndCombination() {
        let target = DTraceTarget.execname("nginx").and(.uid(1000))
        #expect(target.predicate == "(execname == \"nginx\") && (uid == 1000)")
    }

    @Test("Combining all with AND returns other")
    func testAndWithAll() {
        let nginx = DTraceTarget.execname("nginx")
        let combined1 = DTraceTarget.all.and(nginx)
        #expect(combined1.predicate == nginx.predicate)

        let combined2 = nginx.and(.all)
        #expect(combined2.predicate == nginx.predicate)
    }

    @Test("Combining targets with OR")
    func testOrCombination() {
        let target = DTraceTarget.execname("nginx").or(.execname("apache"))
        #expect(target.predicate.contains("||"))
        #expect(target.predicate.contains("nginx"))
        #expect(target.predicate.contains("apache"))
    }

    @Test("Combining with all using OR returns all")
    func testOrWithAll() {
        let nginx = DTraceTarget.execname("nginx")
        let combined1 = DTraceTarget.all.or(nginx)
        #expect(combined1.predicate.isEmpty)

        let combined2 = nginx.or(.all)
        #expect(combined2.predicate.isEmpty)
    }

    @Test("Negating a target")
    func testNegation() {
        let target = DTraceTarget.execname("nginx").negated()
        #expect(target.predicate == "!(execname == \"nginx\")")
    }

    @Test("Negating all target returns all")
    func testNegateAll() {
        let target = DTraceTarget.all.negated()
        #expect(target.predicate.isEmpty)
    }

    @Test("Operators work")
    func testOperators() {
        let target = DTraceTarget.pid(1234) && DTraceTarget.uid(0)
        #expect(target.predicate.contains("&&"))

        let either = DTraceTarget.execname("a") || DTraceTarget.execname("b")
        #expect(either.predicate.contains("||"))

        let not = !DTraceTarget.pid(1)
        #expect(not.predicate.contains("!"))
    }

    @Test("Custom predicate")
    func testCustomPredicate() {
        let target = DTraceTarget.custom("arg0 > 100")
        #expect(target.predicate == "arg0 > 100")
    }

    @Test("Target is Hashable")
    func testHashable() {
        let target1 = DTraceTarget.pid(1234)
        let target2 = DTraceTarget.pid(1234)
        let target3 = DTraceTarget.pid(5678)

        #expect(target1 == target2)
        #expect(target1 != target3)

        let targetSet: Set<DTraceTarget> = [target1, target2, target3]
        #expect(targetSet.count == 2)
    }

    @Test("Target is Sendable")
    func testSendable() {
        // Verify DTraceTarget conforms to Sendable by assigning to a Sendable-constrained function
        func useSendable<T: Sendable>(_ value: T) -> T { value }
        let target = useSendable(DTraceTarget.pid(1234))
        #expect(!target.predicate.isEmpty)
    }

    @Test("Complex target combinations")
    func testComplexCombinations() {
        // (nginx OR apache) AND uid == 0
        let webServers = DTraceTarget.execname("nginx") || DTraceTarget.execname("apache")
        let rootOnly = DTraceTarget.uid(0)
        let combined = webServers && rootOnly

        #expect(combined.predicate.contains("nginx"))
        #expect(combined.predicate.contains("apache"))
        #expect(combined.predicate.contains("uid == 0"))
    }
}

@Suite("DTraceScript Tests")
struct DTraceScriptTests {

    @Test("Empty script")
    func testEmptyScript() {
        let script = DTraceScript()
        let output = script.build()
        #expect(output.isEmpty)
    }

    @Test("Simple script builds correctly")
    func testSimpleScript() {
        let script = DTraceScript("syscall:::entry")
            .action("@[probefunc] = count();")

        let output = script.build()
        #expect(output.contains("syscall:::entry"))
        #expect(output.contains("@[probefunc] = count();"))
    }

    @Test("Script with target builds predicate")
    func testScriptWithTarget() {
        let script = DTraceScript("syscall:::entry")
            .targeting(.pid(1234))
            .action("trace(arg0);")

        let output = script.build()
        #expect(output.contains("/pid == 1234/"))
    }

    @Test("Script with when predicate")
    func testWhenPredicate() {
        let script = DTraceScript("syscall::read:return")
            .when("arg0 > 0")
            .action("@bytes = sum(arg0);")

        let output = script.build()
        #expect(output.contains("arg0 > 0"))
    }

    @Test("Printf helper formats correctly")
    func testPrintfHelper() {
        let script = DTraceScript("syscall::open:entry")
            .printf("opened: %s", "copyinstr(arg0)")

        let output = script.build()
        #expect(output.contains("printf"))
        #expect(output.contains("copyinstr(arg0)"))
    }

    @Test("Printf with no args")
    func testPrintfNoArgs() {
        let script = DTraceScript("syscall:::entry")
            .printf("syscall fired")

        let output = script.build()
        #expect(output.contains("printf(\"syscall fired\\n\")"))
    }

    @Test("Printf with multiple args")
    func testPrintfMultipleArgs() {
        let script = DTraceScript("syscall:::entry")
            .printf("%s[%d]: %s", "execname", "pid", "probefunc")

        let output = script.build()
        #expect(output.contains("execname"))
        #expect(output.contains("pid"))
        #expect(output.contains("probefunc"))
    }

    @Test("Count helper formats correctly")
    func testCountHelper() {
        let script = DTraceScript("syscall:::entry")
            .count(by: "execname")

        let output = script.build()
        #expect(output.contains("@[execname] = count();"))
    }

    @Test("Count with default key")
    func testCountDefaultKey() {
        let script = DTraceScript("syscall:::entry")
            .count()

        let output = script.build()
        #expect(output.contains("@[probefunc] = count();"))
    }

    @Test("Sum helper formats correctly")
    func testSumHelper() {
        let script = DTraceScript("syscall::read:return")
            .sum("arg0", by: "execname")

        let output = script.build()
        #expect(output.contains("@[execname] = sum(arg0);"))
    }

    @Test("Quantize helper formats correctly")
    func testQuantizeHelper() {
        let script = DTraceScript("syscall:::return")
            .quantize("arg0")

        let output = script.build()
        #expect(output.contains("quantize(arg0)"))
    }

    @Test("LQuantize helper formats correctly")
    func testLQuantizeHelper() {
        let script = DTraceScript("syscall::read:return")
            .lquantize("arg0", low: 0, high: 1000, step: 100)

        let output = script.build()
        #expect(output.contains("lquantize(arg0, 0, 1000, 100)"))
    }

    @Test("Min helper formats correctly")
    func testMinHelper() {
        let script = DTraceScript("syscall::read:return")
            .min("arg0", by: "execname")

        let output = script.build()
        #expect(output.contains("@[execname] = min(arg0);"))
    }

    @Test("Max helper formats correctly")
    func testMaxHelper() {
        let script = DTraceScript("syscall::read:return")
            .max("arg0", by: "execname")

        let output = script.build()
        #expect(output.contains("@[execname] = max(arg0);"))
    }

    @Test("Avg helper formats correctly")
    func testAvgHelper() {
        let script = DTraceScript("syscall::read:return")
            .avg("arg0", by: "execname")

        let output = script.build()
        #expect(output.contains("@[execname] = avg(arg0);"))
    }

    @Test("Stack trace helper")
    func testStackHelper() {
        let kernelScript = DTraceScript("fbt:::entry")
            .stack()

        #expect(kernelScript.build().contains("stack();"))

        let userlandScript = DTraceScript("pid$target:::entry")
            .stack(userland: true)

        #expect(userlandScript.build().contains("ustack();"))
    }

    @Test("Trace helper")
    func testTraceHelper() {
        let script = DTraceScript("syscall::open:entry")
            .trace("arg0")

        let output = script.build()
        #expect(output.contains("trace(arg0);"))
    }

    @Test("Multiple probes in script")
    func testMultipleProbes() {
        let script = DTraceScript("syscall::open:entry")
            .action("self->ts = timestamp;")
            .probe("syscall::open:return")
            .action("@[execname] = quantize(timestamp - self->ts);")

        let output = script.build()
        #expect(output.contains("syscall::open:entry"))
        #expect(output.contains("syscall::open:return"))
        #expect(output.contains("self->ts"))
        #expect(output.contains("quantize"))
    }

    @Test("Multiple probes with different targets")
    func testMultipleProbesWithTargets() {
        let script = DTraceScript("syscall::read:entry")
            .targeting(.execname("nginx"))
            .action("self->ts = timestamp;")
            .probe("syscall::read:return")
            .targeting(.execname("nginx"))
            .action("@[probefunc] = quantize(timestamp - self->ts);")

        let output = script.build()
        #expect(output.contains("syscall::read:entry"))
        #expect(output.contains("syscall::read:return"))
        #expect(output.contains("execname == \"nginx\""))
    }

    @Test("Predefined syscall counts script")
    func testSyscallCountsScript() {
        let script = DTraceScript.syscallCounts(for: .execname("test"))
        let output = script.build()

        #expect(output.contains("syscall:freebsd::entry"))
        #expect(output.contains("execname == \"test\""))
        #expect(output.contains("count()"))
    }

    @Test("Predefined syscall counts without target")
    func testSyscallCountsNoTarget() {
        let script = DTraceScript.syscallCounts()
        let output = script.build()

        #expect(output.contains("syscall:freebsd::entry"))
        #expect(output.contains("count()"))
    }

    @Test("Predefined file opens script")
    func testFileOpensScript() {
        let script = DTraceScript.fileOpens()
        let output = script.build()

        #expect(output.contains("syscall:freebsd:open"))
        #expect(output.contains("copyinstr"))
    }

    @Test("Predefined file opens with target")
    func testFileOpensWithTarget() {
        let script = DTraceScript.fileOpens(for: .pid(1234))
        let output = script.build()

        #expect(output.contains("syscall:freebsd:open"))
        #expect(output.contains("pid == 1234"))
    }

    @Test("Predefined CPU profile script")
    func testCpuProfileScript() {
        let script = DTraceScript.cpuProfile(hz: 99)
        let output = script.build()

        #expect(output.contains("profile-99"))
        #expect(output.contains("count()"))
    }

    @Test("Predefined CPU profile with target")
    func testCpuProfileWithTarget() {
        let script = DTraceScript.cpuProfile(for: .execname("myapp"))
        let output = script.build()

        #expect(output.contains("profile-997"))  // default hz
        #expect(output.contains("execname == \"myapp\""))
    }

    @Test("Predefined process exec script")
    func testProcessExecScript() {
        let script = DTraceScript.processExec()
        let output = script.build()

        #expect(output.contains("proc:::exec-success"))
        #expect(output.contains("execname"))
        #expect(output.contains("pid"))
    }

    @Test("Predefined I/O bytes script")
    func testIoBytesScript() {
        let script = DTraceScript.ioBytes()
        let output = script.build()

        #expect(output.contains("syscall:freebsd:read:return"))
        #expect(output.contains("syscall:freebsd:write:return"))
        #expect(output.contains("sum(arg0)"))
    }

    @Test("Predefined I/O bytes with target")
    func testIoBytesWithTarget() {
        let script = DTraceScript.ioBytes(for: .execname("postgres"))
        let output = script.build()

        #expect(output.contains("syscall:freebsd:read:return"))
        #expect(output.contains("syscall:freebsd:write:return"))
        #expect(output.contains("execname == \"postgres\""))
    }

    @Test("Predefined syscall latency script")
    func testSyscallLatencyScript() {
        let script = DTraceScript.syscallLatency("read")
        let output = script.build()

        #expect(output.contains("syscall:freebsd:read:entry"))
        #expect(output.contains("syscall:freebsd:read:return"))
        #expect(output.contains("timestamp"))
        #expect(output.contains("quantize"))
    }

    @Test("Predefined syscall latency with target")
    func testSyscallLatencyWithTarget() {
        let script = DTraceScript.syscallLatency("write", for: .uid(0))
        let output = script.build()

        #expect(output.contains("syscall:freebsd:write:entry"))
        #expect(output.contains("syscall:freebsd:write:return"))
        #expect(output.contains("uid == 0"))
    }

    @Test("Script description matches build")
    func testDescription() {
        let script = DTraceScript("test:::probe").action("/* test */")
        #expect(script.description == script.build())
    }

    @Test("Script is Sendable")
    func testSendable() {
        // Verify DTraceScript conforms to Sendable by assigning to a Sendable-constrained function
        func useSendable<T: Sendable>(_ value: T) -> T { value }
        let script = useSendable(DTraceScript("syscall:::entry").count())
        #expect(!script.build().isEmpty)
    }
}

@Suite("DTraceOutput Tests")
struct DTraceOutputTests {

    @Test("Output enum cases exist")
    func testOutputCases() {
        _ = DTraceOutput.stdout
        _ = DTraceOutput.stderr
        _ = DTraceOutput.null
        _ = DTraceOutput.file("/tmp/test.log")
        _ = DTraceOutput.fileDescriptor(1)  // stdout fd
    }

    @Test("Output buffer captures content")
    func testOutputBuffer() {
        let buffer = DTraceOutputBuffer()
        #expect(buffer.contents.isEmpty)
    }

    @Test("Output buffer can be cleared")
    func testOutputBufferClear() {
        let buffer = DTraceOutputBuffer()
        // The buffer starts empty
        #expect(buffer.contents.isEmpty)
        buffer.clear()
        #expect(buffer.contents.isEmpty)
    }

    @Test("Output is Sendable")
    func testOutputSendable() {
        // Verify DTraceOutput conforms to Sendable by assigning to a Sendable-constrained function
        func useSendable<T: Sendable>(_ value: T) -> T { value }
        let output = useSendable(DTraceOutput.stdout)
        _ = output
    }

    @Test("Buffer output case")
    func testBufferOutputCase() {
        let buffer = DTraceOutputBuffer()
        let output = DTraceOutput.buffer(buffer)
        _ = output  // Just verify it compiles
    }
}

@Suite("DTraceSession Tests")
struct DTraceSessionTests {

    @Test("Aggregation key expressions")
    func testAggregationKeys() {
        #expect(DTraceSession.AggregationKey.function.expression == "probefunc")
        #expect(DTraceSession.AggregationKey.execname.expression == "execname")
        #expect(DTraceSession.AggregationKey.pid.expression == "pid")
        #expect(DTraceSession.AggregationKey.uid.expression == "uid")
        #expect(DTraceSession.AggregationKey.cpu.expression == "cpu")
        #expect(DTraceSession.AggregationKey.custom("mykey").expression == "mykey")
    }

    @Test("Aggregation key is Sendable")
    func testAggregationKeySendable() {
        // Verify AggregationKey conforms to Sendable by assigning to a Sendable-constrained function
        func useSendable<T: Sendable>(_ value: T) -> T { value }
        let key = useSendable(DTraceSession.AggregationKey.function)
        #expect(key.expression == "probefunc")
    }
}

@Suite("DTraceBuilder Tests")
struct DTraceBuilderTests {

    @Test("DTraceBuilder version is available")
    func testVersion() {
        #expect(DTraceBuilder.version == "1.0.0")
    }

    @Test("DTraceCore is re-exported")
    func testDTraceCoreReExported() {
        // Verify DTraceCore types are accessible via DTraceBuilder
        let version = DTraceCore.version
        #expect(version > 0)

        let flags: DTraceOpenFlags = [.noDevice]
        #expect(flags.rawValue == 0x01)
    }
}
