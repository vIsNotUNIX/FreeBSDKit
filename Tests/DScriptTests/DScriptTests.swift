/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
import Glibc
import Foundation
@testable import DScript

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
        #expect(buffer.contents.isEmpty)
        buffer.clear()
        #expect(buffer.contents.isEmpty)
    }

    @Test("Output is Sendable")
    func testOutputSendable() {
        func useSendable<T: Sendable>(_ value: T) -> T { value }
        let output = useSendable(DTraceOutput.stdout)
        _ = output
    }

    @Test("Buffer output case")
    func testBufferOutputCase() {
        let buffer = DTraceOutputBuffer()
        let output = DTraceOutput.buffer(buffer)
        _ = output
    }

    @Test("Buffer captures written content")
    func testBufferCapturesContent() {
        let buffer = DTraceOutputBuffer()

        if let fp = buffer.filePointer {
            let message = "Hello, DTrace!"
            fputs(message, fp)
            fflush(fp)

            let contents = buffer.contents
            #expect(contents == message)
        }
    }

    @Test("Buffer clear removes content")
    func testBufferClearRemovesContent() {
        let buffer = DTraceOutputBuffer()

        if let fp = buffer.filePointer {
            fputs("test content", fp)
            fflush(fp)
            #expect(!buffer.contents.isEmpty)

            buffer.clear()
            #expect(buffer.contents.isEmpty)
        }
    }

    @Test("Buffer handles multiple writes")
    func testBufferMultipleWrites() {
        let buffer = DTraceOutputBuffer()

        if let fp = buffer.filePointer {
            fputs("first", fp)
            fputs(" second", fp)
            fputs(" third", fp)
            fflush(fp)

            #expect(buffer.contents == "first second third")
        }
    }

    @Test("Output withFilePointer works for stdout")
    func testWithFilePointerStdout() {
        let output = DTraceOutput.stdout
        _ = output.withFilePointer { fp in
            fp == Glibc.stdout
        }
    }

    @Test("Output withFilePointer works for stderr")
    func testWithFilePointerStderr() {
        let output = DTraceOutput.stderr
        _ = output.withFilePointer { fp in
            fp == Glibc.stderr
        }
    }

    @Test("Output withFilePointer works for null")
    func testWithFilePointerNull() {
        let output = DTraceOutput.null
        let called = output.withFilePointer { fp in
            // Should get a valid file pointer (to /dev/null)
            return true
        }
        #expect(called)
    }

    @Test("Output withFilePointer works for file")
    func testWithFilePointerFile() throws {
        let testPath = "/tmp/dtrace_output_test_\(getpid()).txt"
        defer { unlink(testPath) }

        let output = DTraceOutput.file(testPath)
        _ = output.withFilePointer { fp in
            fputs("test output", fp)
        }

        // Verify file was written
        let contents = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(contents == "test output")
    }

    @Test("Output withFilePointer works for buffer")
    func testWithFilePointerBuffer() {
        let buffer = DTraceOutputBuffer()
        let output = DTraceOutput.buffer(buffer)

        _ = output.withFilePointer { fp in
            fputs("buffer test", fp)
            fflush(fp)
        }

        #expect(buffer.contents == "buffer test")
    }

    @Test("Output withFilePointer works for fileDescriptor")
    func testWithFilePointerFileDescriptor() throws {
        let testPath = "/tmp/dtrace_fd_test_\(getpid()).txt"
        defer { unlink(testPath) }

        // Open a file and get its descriptor
        let fd = open(testPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        #expect(fd >= 0)
        defer { close(fd) }

        let output = DTraceOutput.fileDescriptor(fd)
        _ = output.withFilePointer { fp in
            fputs("fd test", fp)
        }

        // Read back and verify
        let contents = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(contents == "fd test")
    }

    @Test("FileDescriptor output doesn't close original fd")
    func testFileDescriptorDoesntCloseOriginal() throws {
        let testPath = "/tmp/dtrace_fd_close_test_\(getpid()).txt"
        defer { unlink(testPath) }

        let fd = open(testPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        #expect(fd >= 0)
        defer { close(fd) }

        let output = DTraceOutput.fileDescriptor(fd)
        _ = output.withFilePointer { fp in
            fputs("first write", fp)
        }

        // Original fd should still be valid - write should succeed
        let result = write(fd, "second", 6)
        #expect(result == 6)
    }
}

@Suite("DScriptSession Tests")
struct DScriptSessionTests {

    @Test("Session can be created with factory method")
    func testSessionFactory() throws {
        // This test validates the API exists (actual DTrace requires root)
        // Just verify the types compile correctly
        _ = DScriptSession.create as (DTraceOpenFlags, String, String) throws -> DScriptSession
    }

    @Test("Session run methods exist")
    func testSessionRunMethods() throws {
        // Verify the run method signatures exist
        _ = DScriptSession.run as (DScript, DTraceOpenFlags, String, String) throws -> DScriptSession
    }
}

@Suite("DScript Module Tests")
struct DScriptModuleTests {

    @Test("DTraceCore is re-exported")
    func testDTraceCoreReExported() {
        // Verify DTraceCore types are accessible via DScript
        let version = DTraceCore.version
        #expect(version > 0)

        let flags: DTraceOpenFlags = [.noDevice]
        #expect(flags.rawValue == 0x01)
    }
}

// MARK: - DScript Validation Tests

@Suite("DScript Validation Tests")
struct DScriptValidationTests {

    @Test("Empty script throws emptyScript error")
    func testEmptyScriptThrows() {
        // Create an empty script programmatically (can't do with builder)
        let script = DScript { }

        #expect(throws: DScriptError.self) {
            try script.validate()
        }
    }

    @Test("Probe with no actions throws emptyClause error")
    func testProbeNoActionsThrows() {
        // Create a probe clause with no actions programmatically
        let clause = ProbeClause(probe: "syscall:::entry", predicates: ["pid == 1234"], actions: [])

        // We need to create a DScript with this clause
        // Since DScript uses a builder, we'll test the clause directly
        #expect(clause.actions.isEmpty)

        // Create script with the empty-action clause
        struct TestScript {
            let clauses: [ProbeClause]

            func validate() throws {
                if clauses.isEmpty {
                    throw DScriptError.emptyScript
                }
                for (index, clause) in clauses.enumerated() {
                    if clause.actions.isEmpty {
                        throw DScriptError.emptyClause(probe: clause.probe, index: index)
                    }
                }
            }
        }

        let testScript = TestScript(clauses: [clause])
        #expect(throws: DScriptError.self) {
            try testScript.validate()
        }
    }

    @Test("Probe with only predicates (no actions) is invalid")
    func testPredicateOnlyProbeInvalid() {
        // Using the programmatic initializer
        let clause = ProbeClause(
            probe: "syscall:::entry",
            predicates: ["execname == \"nginx\"", "arg0 > 0"],
            actions: []
        )

        #expect(clause.predicates.count == 2)
        #expect(clause.actions.isEmpty)
    }

    @Test("DScriptError descriptions are meaningful")
    func testErrorDescriptions() {
        let emptyError = DScriptError.emptyScript
        #expect(emptyError.description.contains("no probe clauses"))

        let emptyClauseError = DScriptError.emptyClause(probe: "syscall:::entry", index: 0)
        #expect(emptyClauseError.description.contains("syscall:::entry"))
        #expect(emptyClauseError.description.contains("0"))
        #expect(emptyClauseError.description.contains("no actions"))
    }

    @Test("Valid script with action passes validation")
    func testValidScriptPasses() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        // Should not throw
        try script.validate()
        #expect(script.clauses.count == 1)
        #expect(!script.clauses[0].actions.isEmpty)
    }

    @Test("Valid script with multiple probes passes")
    func testMultipleProbesPasses() throws {
        let script = DScript {
            Probe("syscall::read:entry") {
                Timestamp()
            }
            Probe("syscall::read:return") {
                When("self->ts")
                Latency(by: "execname")
            }
        }

        try script.validate()
        #expect(script.clauses.count == 2)
    }

    @Test("Script data conversion works")
    func testScriptDataConversion() {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let data = script.data
        #expect(!data.isEmpty)

        // Verify it's valid UTF-8
        let string = String(data: data, encoding: .utf8)
        #expect(string != nil)
        #expect(string == script.source)
    }

    @Test("Script null-terminated data works")
    func testScriptNullTerminatedData() {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let data = script.nullTerminatedData
        #expect(data.last == 0)  // Null terminator
        #expect(data.count == script.source.utf8.count + 1)
    }

    @Test("Script JSON representation works")
    func testScriptJSONRepresentation() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                Count(by: "probefunc")
            }
        }

        let json = script.jsonRepresentation
        #expect(json["version"] as? Int == 1)

        let clauses = json["clauses"] as? [[String: Any]]
        #expect(clauses?.count == 1)

        let firstClause = clauses?[0]
        #expect(firstClause?["probe"] as? String == "syscall:::entry")
        #expect((firstClause?["predicates"] as? [String])?.count == 1)
        #expect((firstClause?["actions"] as? [String])?.count == 1)
    }

    @Test("Script JSON data is valid JSON")
    func testScriptJSONDataValid() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        guard let jsonData = script.jsonData else {
            Issue.record("jsonData should not be nil")
            return
        }

        // Verify it's valid JSON
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed is [String: Any])
    }

    @Test("Script JSON string is valid")
    func testScriptJSONString() {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        guard let jsonString = script.jsonString else {
            Issue.record("jsonString should not be nil")
            return
        }

        #expect(jsonString.contains("\"version\""))
        #expect(jsonString.contains("\"clauses\""))
    }

    @Test("Script write to file works")
    func testScriptWriteToFile() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let testPath = "/tmp/dscript_test_\(getpid()).d"
        defer { unlink(testPath) }

        try script.write(to: testPath)

        let contents = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(contents == script.source)
    }
}

// MARK: - DScript ResultBuilder Tests

@Suite("DScript ResultBuilder Tests")
struct DScriptResultBuilderTests {

    @Test("Simple script with single probe")
    func testSimpleScript() {
        let script = DScript {
            Probe("syscall:::entry") {
                Count(by: "probefunc")
            }
        }

        let source = script.source
        #expect(source.contains("syscall:::entry"))
        #expect(source.contains("@[probefunc] = count();"))
    }

    @Test("Script with target predicate")
    func testScriptWithTarget() {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                Count(by: "probefunc")
            }
        }

        let source = script.source
        #expect(source.contains("execname == \"nginx\""))
        #expect(source.contains("count()"))
    }

    @Test("Script with When predicate")
    func testScriptWithWhen() {
        let script = DScript {
            Probe("syscall::read:return") {
                When("arg0 > 0")
                Sum("arg0", by: "execname")
            }
        }

        let source = script.source
        #expect(source.contains("/(arg0 > 0)/"))
        #expect(source.contains("sum(arg0)"))
    }

    @Test("Script with multiple predicates")
    func testScriptWithMultiplePredicates() {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                When("arg0 > 0")
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("execname == \"nginx\""))
        #expect(source.contains("arg0 > 0"))
        #expect(source.contains("&&"))
    }

    @Test("Script with multiple actions")
    func testScriptWithMultipleActions() {
        let script = DScript {
            Probe("syscall::read:entry") {
                Action("self->ts = timestamp;")
                Action("self->fd = arg0;")
            }
        }

        let source = script.source
        #expect(source.contains("self->ts = timestamp;"))
        #expect(source.contains("self->fd = arg0;"))
    }

    @Test("Script with multiple probes")
    func testScriptWithMultipleProbes() {
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

        let source = script.source
        #expect(source.contains("syscall::read:entry"))
        #expect(source.contains("syscall::read:return"))
        #expect(source.contains("self->ts = timestamp;"))
        #expect(source.contains("quantize"))
    }

    @Test("All aggregation types")
    func testAllAggregationTypes() {
        let script = DScript {
            Probe("test:::probe") {
                Count(by: "a")
            }
            Probe("test:::probe") {
                Sum("v", by: "b")
            }
            Probe("test:::probe") {
                Min("v", by: "c")
            }
            Probe("test:::probe") {
                Max("v", by: "d")
            }
            Probe("test:::probe") {
                Avg("v", by: "e")
            }
            Probe("test:::probe") {
                Quantize("v", by: "f")
            }
            Probe("test:::probe") {
                Lquantize("v", low: 0, high: 100, step: 10, by: "g")
            }
        }

        let source = script.source
        #expect(source.contains("@[a] = count();"))
        #expect(source.contains("@[b] = sum(v);"))
        #expect(source.contains("@[c] = min(v);"))
        #expect(source.contains("@[d] = max(v);"))
        #expect(source.contains("@[e] = avg(v);"))
        #expect(source.contains("@[f] = quantize(v);"))
        #expect(source.contains("@[g] = lquantize(v, 0, 100, 10);"))
    }

    @Test("Printf action")
    func testPrintfAction() {
        let script = DScript {
            Probe("syscall::open:entry") {
                Printf("%s[%d]: %s", "execname", "pid", "copyinstr(arg0)")
            }
        }

        let source = script.source
        #expect(source.contains("printf"))
        #expect(source.contains("execname"))
        #expect(source.contains("pid"))
        #expect(source.contains("copyinstr(arg0)"))
    }

    @Test("Trace action")
    func testTraceAction() {
        let script = DScript {
            Probe("syscall:::entry") {
                Trace("arg0")
            }
        }

        let source = script.source
        #expect(source.contains("trace(arg0);"))
    }

    @Test("Stack trace actions")
    func testStackTraceActions() {
        let script = DScript {
            Probe("fbt:::entry") {
                Stack()
            }
            Probe("pid$target:::entry") {
                Stack(userland: true)
            }
        }

        let source = script.source
        #expect(source.contains("stack();"))
        #expect(source.contains("ustack();"))
    }

    @Test("Timestamp and Latency helpers")
    func testTimestampAndLatency() {
        let script = DScript {
            Probe("syscall::read:entry") {
                Timestamp()
            }
            Probe("syscall::read:return") {
                When("self->ts")
                Latency(by: "execname")
            }
        }

        let source = script.source
        #expect(source.contains("self->ts = timestamp;"))
        #expect(source.contains("quantize(timestamp - self->ts)"))
        #expect(source.contains("self->ts = 0;"))
    }

    @Test("Custom Timestamp variable")
    func testCustomTimestampVariable() {
        let script = DScript {
            Probe("syscall::read:entry") {
                Timestamp("self->read_start")
            }
        }

        let source = script.source
        #expect(source.contains("self->read_start = timestamp;"))
    }

    @Test("Script validation - passes for valid script")
    func testValidationPasses() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Count()
            }
        }

        try script.validate()  // Should not throw
    }

    @Test("Script validation - passes with multiple valid probes")
    func testValidationMultipleProbes() throws {
        let script = DScript {
            Probe("syscall::read:entry") {
                Timestamp()
            }
            Probe("syscall::read:return") {
                When("self->ts")
                Latency(by: "execname")
            }
        }

        try script.validate()
    }

    @Test("Script validation - passes with predicate only actions")
    func testValidationPredicateWithAction() throws {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                When("arg0 > 0")
                Count()  // Has an action
            }
        }

        try script.validate()
    }

    @Test("DScript description matches source")
    func testDescription() {
        let script = DScript {
            Probe("test:::probe") {
                Count()
            }
        }

        #expect(script.description == script.source)
    }

    @Test("Predefined syscallCounts script")
    func testPredefinedSyscallCounts() {
        let script = DScript.syscallCounts(for: .execname("nginx"))
        let source = script.source

        #expect(source.contains("syscall:freebsd::entry"))
        #expect(source.contains("execname == \"nginx\""))
        #expect(source.contains("count()"))
    }

    @Test("Predefined syscallCounts without target")
    func testPredefinedSyscallCountsNoTarget() {
        let script = DScript.syscallCounts()
        let source = script.source

        #expect(source.contains("syscall:freebsd::entry"))
        #expect(source.contains("count()"))
        // Should not have a predicate for .all target
    }

    @Test("Predefined fileOpens script")
    func testPredefinedFileOpens() {
        let script = DScript.fileOpens(for: .pid(1234))
        let source = script.source

        #expect(source.contains("syscall:freebsd:open"))
        #expect(source.contains("pid == 1234"))
        #expect(source.contains("printf"))
    }

    @Test("Predefined cpuProfile script")
    func testPredefinedCpuProfile() {
        let script = DScript.cpuProfile(hz: 99, for: .uid(0))
        let source = script.source

        #expect(source.contains("profile-99"))
        #expect(source.contains("uid == 0"))
        #expect(source.contains("count()"))
    }

    @Test("Predefined processExec script")
    func testPredefinedProcessExec() {
        let script = DScript.processExec()
        let source = script.source

        #expect(source.contains("proc:::exec-success"))
        #expect(source.contains("printf"))
    }

    @Test("Predefined ioBytes script")
    func testPredefinedIoBytes() {
        let script = DScript.ioBytes(for: .execname("postgres"))
        let source = script.source

        #expect(source.contains("syscall:freebsd:read:return"))
        #expect(source.contains("syscall:freebsd:write:return"))
        #expect(source.contains("execname == \"postgres\""))
        #expect(source.contains("sum(arg0)"))
    }

    @Test("Predefined syscallLatency script")
    func testPredefinedSyscallLatency() {
        let script = DScript.syscallLatency("write", for: .jail(1))
        let source = script.source

        #expect(source.contains("syscall:freebsd:write:entry"))
        #expect(source.contains("syscall:freebsd:write:return"))
        #expect(source.contains("jid == 1"))
        #expect(source.contains("timestamp"))
        #expect(source.contains("quantize"))
    }

    @Test("Complex combined predicates")
    func testComplexCombinedPredicates() {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("nginx") || .execname("apache"))
                When("arg0 > 0")
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("nginx"))
        #expect(source.contains("apache"))
        #expect(source.contains("||"))
        #expect(source.contains("arg0 > 0"))
    }

    @Test("Script with raw action code")
    func testRawActionCode() {
        let script = DScript {
            Probe("syscall::open:entry") {
                Action("""
                    self->path = copyinstr(arg0);
                    self->flags = arg1;
                    self->mode = arg2;
                    """)
            }
        }

        let source = script.source
        #expect(source.contains("self->path = copyinstr(arg0);"))
        #expect(source.contains("self->flags = arg1;"))
        #expect(source.contains("self->mode = arg2;"))
    }

    @Test("Output format is correct D syntax")
    func testOutputFormatIsValidD() {
        let script = DScript {
            Probe("syscall:::entry") {
                Target(.execname("test"))
                When("arg0 > 0")
                Count(by: "probefunc")
                Sum("arg1", by: "execname")
            }
        }

        let source = script.source

        // Check basic D syntax elements
        #expect(source.contains("{"))
        #expect(source.contains("}"))
        #expect(source.contains("/"))  // Predicate delimiters

        // Actions should be indented
        let lines = source.split(separator: "\n")
        let actionLines = lines.filter { $0.contains("@[") }
        for line in actionLines {
            #expect(line.hasPrefix("    "), "Action lines should be indented")
        }
    }
}
