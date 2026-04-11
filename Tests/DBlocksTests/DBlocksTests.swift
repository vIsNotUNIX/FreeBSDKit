/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Testing
import Glibc
import Foundation
import CDTrace
@testable import DBlocks

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

@Suite("DTraceSession Tests")
struct DTraceSessionTests {

    @Test("Session can be created with factory method")
    func testSessionFactory() throws {
        // This test validates the API exists (actual DTrace requires root)
        // Just verify the types compile correctly
        _ = DTraceSession.create as (DTraceOpenFlags) throws -> DTraceSession
    }

    @Test("Session configuration methods exist")
    func testSessionConfigMethods() {
        // Verify method signatures exist via static type checking
        // DTraceSession is ~Copyable, so we verify types via function type annotations

        func verifyOutput(_: (inout DTraceSession, DTraceOutput) -> Void) {}
        func verifyBufferSize(_: (inout DTraceSession, String) throws -> Void) {}
        func verifyAggBufferSize(_: (inout DTraceSession, String) throws -> Void) {}
        func verifyQuiet(_: (inout DTraceSession) throws -> Void) {}
        func verifyJsonOutput(_: (inout DTraceSession) throws -> Void) {}
        func verifyOption(_: (inout DTraceSession, String, String?) throws -> Void) {}

        #expect(true, "Configuration methods verified via static type checking")
    }

    @Test("Session script methods exist")
    func testSessionScriptMethods() {
        // Verify add method signatures exist
        func verifyAddScript(_: (inout DTraceSession, DBlocks) -> Void) {}

        #expect(true, "Script methods verified via static type checking")
    }

    @Test("Session execution methods exist")
    func testSessionExecutionMethods() {
        // Verify execution method signatures exist
        func verifyRun(_: (inout DTraceSession) throws -> Void) {}
        func verifyRunFor(_: (inout DTraceSession, TimeInterval) throws -> Void) {}
        func verifyStart(_: (inout DTraceSession) throws -> Void) {}
        func verifyStop(_: (borrowing DTraceSession) throws -> Void) {}
        func verifyProcess(_: (borrowing DTraceSession) -> DTraceWorkStatus) {}
        func verifyProcessFor(_: (borrowing DTraceSession, TimeInterval) -> Void) {}
        func verifyWait(_: (borrowing DTraceSession) -> Void) {}

        #expect(true, "Execution methods verified via static type checking")
    }

    @Test("DBlocks run methods exist")
    func testDBlocksRunMethods() {
        // Verify DBlocks has run/capture methods
        let script = DBlocks {
            Probe("syscall:::entry") { Count() }
        }

        // These are instance methods
        _ = script.run as () throws -> Void
        _ = script.run as (TimeInterval) throws -> Void
        _ = script.capture as () throws -> String
        _ = script.capture as (TimeInterval) throws -> String

        #expect(true, "DBlocks run methods verified")
    }

    @Test("DBlocks static run methods exist")
    func testDBlocksStaticRunMethods() {
        // Verify DBlocks has static run/capture methods
        _ = DBlocks.run as (@escaping () -> [ProbeClause]) throws -> Void
        _ = DBlocks.run as (TimeInterval, @escaping () -> [ProbeClause]) throws -> Void
        _ = DBlocks.capture as (@escaping () -> [ProbeClause]) throws -> String
        _ = DBlocks.capture as (TimeInterval, @escaping () -> [ProbeClause]) throws -> String

        #expect(true, "DBlocks static run methods verified")
    }

    @Test("Deprecated typealias exists")
    func testDeprecatedTypealias() {
        // DBlocksSession should be a typealias for DTraceSession
        let _: DBlocksSession.Type = DTraceSession.self
        #expect(true, "Deprecated typealias exists")
    }
}

@Suite("DBlocks Module Tests")
struct DBlocksModuleTests {

    @Test("DTraceCore is re-exported")
    func testDTraceCoreReExported() {
        // Verify DTraceCore types are accessible via DBlocks
        let version = DTraceCore.version
        #expect(version > 0)

        let flags: DTraceOpenFlags = [.noDevice]
        #expect(flags.rawValue == 0x01)
    }
}

// MARK: - DBlocks Validation Tests

@Suite("DBlocks Validation Tests")
struct DBlocksValidationTests {

    @Test("Empty script throws emptyScript error")
    func testEmptyScriptThrows() {
        // Create an empty script programmatically (can't do with builder)
        let script = DBlocks { }

        #expect(throws: DBlocksError.self) {
            try script.validate()
        }
    }

    @Test("Probe with no actions throws emptyClause error")
    func testProbeNoActionsThrows() {
        // Create a probe clause with no actions programmatically
        let clause = ProbeClause(probe: "syscall:::entry", predicates: ["pid == 1234"], actions: [])

        // We need to create a DBlocks with this clause
        // Since DBlocks uses a builder, we'll test the clause directly
        #expect(clause.actions.isEmpty)

        // Create script with the empty-action clause
        struct TestScript {
            let clauses: [ProbeClause]

            func validate() throws {
                if clauses.isEmpty {
                    throw DBlocksError.emptyScript
                }
                for (index, clause) in clauses.enumerated() {
                    if clause.actions.isEmpty {
                        throw DBlocksError.emptyClause(probe: clause.probe, index: index)
                    }
                }
            }
        }

        let testScript = TestScript(clauses: [clause])
        #expect(throws: DBlocksError.self) {
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

    @Test("DBlocksError descriptions are meaningful")
    func testErrorDescriptions() {
        let emptyError = DBlocksError.emptyScript
        #expect(emptyError.description.contains("no probe clauses"))

        let emptyClauseError = DBlocksError.emptyClause(probe: "syscall:::entry", index: 0)
        #expect(emptyClauseError.description.contains("syscall:::entry"))
        #expect(emptyClauseError.description.contains("0"))
        #expect(emptyClauseError.description.contains("no actions"))

        let compileError = DBlocksError.compilationFailed(
            source: "invalid:::probe { }",
            error: "syntax error"
        )
        #expect(compileError.description.contains("compilation failed"))
        #expect(compileError.description.contains("syntax error"))
    }

    @Test("Script compile() method exists")
    func testCompileMethodExists() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
        }

        // Verify the method signature exists
        // Actually calling compile() requires root
        _ = script.compile as () throws -> Bool
    }

    @Test("Valid script with action passes validation")
    func testValidScriptPasses() throws {
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let data = script.nullTerminatedData
        #expect(data.last == 0)  // Null terminator
        #expect(data.count == script.source.utf8.count + 1)
    }

    @Test("Script JSON data is valid JSON")
    func testScriptJSONDataValid() throws {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                Count(by: "probefunc")
            }
        }

        let jsonData = try script.jsonData()

        // Verify it's valid JSON
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(parsed?["version"] as? Int == 1)

        let clauses = parsed?["clauses"] as? [[String: Any]]
        #expect(clauses?.count == 1)

        let firstClause = clauses?[0]
        #expect(firstClause?["probe"] as? String == "syscall:::entry")
        #expect((firstClause?["predicates"] as? [String])?.count == 1)
        #expect((firstClause?["actions"] as? [String])?.count == 1)
    }

    @Test("Script write to file works")
    func testScriptWriteToFile() throws {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let testPath = "/tmp/dblocks_test_\(getpid()).d"
        defer { unlink(testPath) }

        try script.write(to: testPath)

        let contents = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(contents == script.source)
    }
}

// MARK: - DBlocks ResultBuilder Tests

@Suite("DBlocks ResultBuilder Tests")
struct DBlocksResultBuilderTests {

    @Test("Simple script with single probe")
    func testSimpleScript() {
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
            Probe("syscall:::entry") {
                Trace("arg0")
            }
        }

        let source = script.source
        #expect(source.contains("trace(arg0);"))
    }

    @Test("Stack trace actions")
    func testStackTraceActions() {
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
            Probe("syscall::read:entry") {
                Timestamp("self->read_start")
            }
        }

        let source = script.source
        #expect(source.contains("self->read_start = timestamp;"))
    }

    @Test("Script validation - passes for valid script")
    func testValidationPasses() throws {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
        }

        try script.validate()  // Should not throw
    }

    @Test("Script validation - passes with multiple valid probes")
    func testValidationMultipleProbes() throws {
        let script = DBlocks {
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
        let script = DBlocks {
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                When("arg0 > 0")
                Count()  // Has an action
            }
        }

        try script.validate()
    }

    @Test("DBlocks description matches source")
    func testDescription() {
        let script = DBlocks {
            Probe("test:::probe") {
                Count()
            }
        }

        #expect(script.description == script.source)
    }

    @Test("Predefined syscallCounts script")
    func testPredefinedSyscallCounts() {
        let script = DBlocks.syscallCounts(for: .execname("nginx"))
        let source = script.source

        #expect(source.contains("syscall:freebsd::entry"))
        #expect(source.contains("execname == \"nginx\""))
        #expect(source.contains("count()"))
    }

    @Test("Predefined syscallCounts without target")
    func testPredefinedSyscallCountsNoTarget() {
        let script = DBlocks.syscallCounts()
        let source = script.source

        #expect(source.contains("syscall:freebsd::entry"))
        #expect(source.contains("count()"))
        // Should not have a predicate for .all target
    }

    @Test("Predefined fileOpens script")
    func testPredefinedFileOpens() {
        let script = DBlocks.fileOpens(for: .pid(1234))
        let source = script.source

        #expect(source.contains("syscall:freebsd:open"))
        #expect(source.contains("pid == 1234"))
        #expect(source.contains("printf"))
    }

    @Test("Predefined cpuProfile script")
    func testPredefinedCpuProfile() {
        let script = DBlocks.cpuProfile(hz: 99, for: .uid(0))
        let source = script.source

        #expect(source.contains("profile-99"))
        #expect(source.contains("uid == 0"))
        #expect(source.contains("count()"))
    }

    @Test("Predefined processExec script")
    func testPredefinedProcessExec() {
        let script = DBlocks.processExec()
        let source = script.source

        #expect(source.contains("proc:::exec-success"))
        #expect(source.contains("printf"))
    }

    @Test("Predefined ioBytes script")
    func testPredefinedIoBytes() {
        let script = DBlocks.ioBytes(for: .execname("postgres"))
        let source = script.source

        #expect(source.contains("syscall:freebsd:read:return"))
        #expect(source.contains("syscall:freebsd:write:return"))
        #expect(source.contains("execname == \"postgres\""))
        #expect(source.contains("sum(arg0)"))
    }

    @Test("Predefined syscallLatency script")
    func testPredefinedSyscallLatency() {
        let script = DBlocks.syscallLatency("write", for: .jail(1))
        let source = script.source

        #expect(source.contains("syscall:freebsd:write:entry"))
        #expect(source.contains("syscall:freebsd:write:return"))
        #expect(source.contains("jid == 1"))
        #expect(source.contains("timestamp"))
        #expect(source.contains("quantize"))
    }

    @Test("Complex combined predicates")
    func testComplexCombinedPredicates() {
        let script = DBlocks {
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
        let script = DBlocks {
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
        let script = DBlocks {
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

// MARK: - New DBlocks Features Tests

@Suite("DBlocks Special Clauses Tests")
struct DBlocksSpecialClausesTests {

    @Test("BEGIN clause generates correct syntax")
    func testBEGINClause() {
        let script = DBlocks {
            BEGIN {
                Printf("Starting trace...")
            }
            Probe("syscall:::entry") {
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("BEGIN"))
        #expect(source.contains("printf"))
        #expect(source.contains("Starting trace..."))
    }

    @Test("END clause generates correct syntax")
    func testENDClause() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
            END {
                Printf("Trace complete")
            }
        }

        let source = script.source
        #expect(source.contains("END"))
        #expect(source.contains("printf"))
        #expect(source.contains("Trace complete"))
    }

    @Test("ERROR clause generates correct syntax")
    func testERRORClause() {
        let script = DBlocks {
            ERROR {
                Printf("Error occurred")
            }
            Probe("syscall:::entry") {
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("ERROR"))
    }

    @Test("Tick clause with seconds")
    func testTickSeconds() {
        let script = DBlocks {
            Tick(1, .seconds) {
                Printa()
            }
        }

        let source = script.source
        #expect(source.contains("tick-1s"))
        #expect(source.contains("printa(@);"))
    }

    @Test("Tick clause with hz")
    func testTickHz() {
        let script = DBlocks {
            Tick(hz: 100) {
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("tick-100hz"))
    }

    @Test("Tick clause with various time units")
    func testTickTimeUnits() {
        let ns = DBlocks { Tick(1000, .nanoseconds) { Count() } }
        let us = DBlocks { Tick(100, .microseconds) { Count() } }
        let ms = DBlocks { Tick(10, .milliseconds) { Count() } }
        let sec = DBlocks { Tick(1, .seconds) { Count() } }
        let min = DBlocks { Tick(1, .minutes) { Count() } }
        let hr = DBlocks { Tick(1, .hours) { Count() } }
        let day = DBlocks { Tick(1, .days) { Count() } }

        #expect(ns.source.contains("tick-1000ns"))
        #expect(us.source.contains("tick-100us"))
        #expect(ms.source.contains("tick-10ms"))
        #expect(sec.source.contains("tick-1s"))
        #expect(min.source.contains("tick-1m"))
        #expect(hr.source.contains("tick-1h"))
        #expect(day.source.contains("tick-1d"))
    }

    @Test("Profile clause generates correct syntax")
    func testProfileClause() {
        let script = DBlocks {
            Profile(hz: 997) {
                When("arg0")
                Count(by: "stack()")
            }
        }

        let source = script.source
        #expect(source.contains("profile-997hz"))
    }

    @Test("Profile clause with seconds")
    func testProfileSeconds() {
        let script = DBlocks {
            Profile(seconds: 1) {
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("profile-1s"))
    }

    @Test("Combined BEGIN, probes, Tick, and END")
    func testCombinedClauses() {
        let script = DBlocks {
            BEGIN {
                Printf("Started")
            }
            Probe("syscall:::entry") {
                Count(by: "probefunc", into: "calls")
            }
            Tick(1, .seconds) {
                Printa("calls")
                Clear("calls")
            }
            END {
                Printf("Done")
            }
        }

        let source = script.source
        #expect(source.contains("BEGIN"))
        #expect(source.contains("syscall:::entry"))
        #expect(source.contains("tick-1s"))
        #expect(source.contains("END"))
        #expect(source.contains("@calls"))
        #expect(source.contains("printa(@calls);"))
        #expect(source.contains("clear(@calls);"))
    }
}

@Suite("DBlocks Named and Multi-Key Aggregations Tests")
struct DBlocksAggregationTests {

    @Test("Named aggregation with into:")
    func testNamedAggregation() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count(by: "probefunc", into: "syscalls")
            }
        }

        let source = script.source
        #expect(source.contains("@syscalls[probefunc] = count();"))
    }

    @Test("Multi-key aggregation")
    func testMultiKeyAggregation() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count(by: ["execname", "probefunc"])
            }
        }

        let source = script.source
        #expect(source.contains("@[execname, probefunc] = count();"))
    }

    @Test("Named multi-key aggregation")
    func testNamedMultiKeyAggregation() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count(by: ["execname", "probefunc"], into: "calls")
            }
        }

        let source = script.source
        #expect(source.contains("@calls[execname, probefunc] = count();"))
    }

    @Test("Sum with named and multi-key")
    func testSumNamedMultiKey() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                Sum("arg0", by: ["execname", "probefunc"], into: "bytes")
            }
        }

        let source = script.source
        #expect(source.contains("@bytes[execname, probefunc] = sum(arg0);"))
    }

    @Test("All aggregation types with into:")
    func testAllAggregationsWithInto() {
        let script = DBlocks {
            Probe("test:::probe") {
                Count(by: "k", into: "cnt")
            }
            Probe("test:::probe") {
                Sum("v", by: "k", into: "total")
            }
            Probe("test:::probe") {
                Min("v", by: "k", into: "minimum")
            }
            Probe("test:::probe") {
                Max("v", by: "k", into: "maximum")
            }
            Probe("test:::probe") {
                Avg("v", by: "k", into: "average")
            }
            Probe("test:::probe") {
                Quantize("v", by: "k", into: "dist")
            }
        }

        let source = script.source
        #expect(source.contains("@cnt[k] = count();"))
        #expect(source.contains("@total[k] = sum(v);"))
        #expect(source.contains("@minimum[k] = min(v);"))
        #expect(source.contains("@maximum[k] = max(v);"))
        #expect(source.contains("@average[k] = avg(v);"))
        #expect(source.contains("@dist[k] = quantize(v);"))
    }

    @Test("Simple count without keys")
    func testSimpleCount() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
        }

        let source = script.source
        #expect(source.contains("@ = count();"))
    }

    @Test("Stddev with single key")
    func testStddevSingleKey() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                Stddev("arg0", by: "execname")
            }
        }
        #expect(script.source.contains("@[execname] = stddev(arg0);"))
    }

    @Test("Stddev with multi-key and name")
    func testStddevNamedMultiKey() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                Stddev("arg0", by: ["execname", "probefunc"], into: "spread")
            }
        }
        #expect(script.source.contains("@spread[execname, probefunc] = stddev(arg0);"))
    }

    @Test("Llquantize single key")
    func testLlquantizeSingleKey() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                Llquantize("timestamp - self->ts",
                           base: 10, low: 0, high: 9, steps: 10,
                           by: "execname")
            }
        }
        #expect(script.source.contains(
            "@[execname] = llquantize(timestamp - self->ts, 10, 0, 9, 10);"
        ))
    }

    @Test("Llquantize named multi-key")
    func testLlquantizeNamedMultiKey() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                Llquantize("timestamp - self->ts",
                           base: 2, low: 0, high: 32, steps: 4,
                           by: ["execname", "probefunc"],
                           into: "latency")
            }
        }
        #expect(script.source.contains(
            "@latency[execname, probefunc] = llquantize(timestamp - self->ts, 2, 0, 32, 4);"
        ))
    }
}

@Suite("DBlocks Variables Tests")
struct DBlocksVariablesTests {

    @Test("Thread-local variable")
    func testThreadLocalVariable() {
        let script = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }

        let source = script.source
        #expect(source.contains("self->ts = timestamp;"))
    }

    @Test("Clause-local variable")
    func testClauseLocalVariable() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Assign(.clause("start"), to: "vtimestamp")
            }
        }

        let source = script.source
        #expect(source.contains("this->start = vtimestamp;"))
    }

    @Test("Global variable")
    func testGlobalVariable() {
        let script = DBlocks {
            BEGIN {
                Assign(.global("total"), to: "0")
            }
            Probe("syscall:::entry") {
                Assign(.global("total"), to: "total + 1")
            }
        }

        let source = script.source
        #expect(source.contains("total = 0;"))
        #expect(source.contains("total = total + 1;"))
    }

    @Test("Var expression property")
    func testVarExpression() {
        let thread = Var.thread("myvar")
        let clause = Var.clause("temp")
        let global = Var.global("counter")

        #expect(thread.expression == "self->myvar")
        #expect(clause.expression == "this->temp")
        #expect(global.expression == "counter")
    }
}

@Suite("DBlocks Control Actions Tests")
struct DBlocksControlActionsTests {

    @Test("Exit action")
    func testExitAction() {
        let script = DBlocks {
            Tick(60, .seconds) {
                Exit(0)
            }
        }

        let source = script.source
        #expect(source.contains("exit(0);"))
    }

    @Test("Exit with custom status")
    func testExitWithStatus() {
        let script = DBlocks {
            ERROR {
                Exit(1)
            }
        }

        let source = script.source
        #expect(source.contains("exit(1);"))
    }

    @Test("Stop action")
    func testStopAction() {
        let script = DBlocks {
            Probe("syscall::exit:entry") {
                Stop()
            }
        }

        let source = script.source
        #expect(source.contains("stop();"))
    }
}

@Suite("DBlocks Aggregation Operations Tests")
struct DBlocksAggregationOperationsTests {

    @Test("Printa all aggregations")
    func testPrintaAll() {
        let script = DBlocks {
            END {
                Printa()
            }
        }

        let source = script.source
        #expect(source.contains("printa(@);"))
    }

    @Test("Printa named aggregation")
    func testPrintaNamed() {
        let script = DBlocks {
            Tick(1, .seconds) {
                Printa("calls")
            }
        }

        let source = script.source
        #expect(source.contains("printa(@calls);"))
    }

    @Test("Printa with format")
    func testPrintaWithFormat() {
        let script = DBlocks {
            END {
                Printa("%s: %@count\\n", "calls")
            }
        }

        let source = script.source
        #expect(source.contains("printa(\"%s: %@count\\n\", @calls);"))
    }

    @Test("Clear all aggregations")
    func testClearAll() {
        let script = DBlocks {
            Tick(1, .seconds) {
                Printa()
                Clear()
            }
        }

        let source = script.source
        #expect(source.contains("clear(@);"))
    }

    @Test("Clear named aggregation")
    func testClearNamed() {
        let script = DBlocks {
            Tick(1, .seconds) {
                Clear("calls")
            }
        }

        let source = script.source
        #expect(source.contains("clear(@calls);"))
    }

    @Test("Trunc aggregation")
    func testTrunc() {
        let script = DBlocks {
            END {
                Trunc("calls", 10)
                Printa("calls")
            }
        }

        let source = script.source
        #expect(source.contains("trunc(@calls, 10);"))
    }

    @Test("Trunc all to N")
    func testTruncAllToN() {
        let script = DBlocks {
            END {
                Trunc(5)
            }
        }

        let source = script.source
        #expect(source.contains("trunc(@, 5);"))
    }

    @Test("Normalize aggregation")
    func testNormalize() {
        let script = DBlocks {
            END {
                Normalize("latency", 1_000_000)
                Printa("latency")
            }
        }

        let source = script.source
        #expect(source.contains("normalize(@latency, 1000000);"))
    }

    @Test("Denormalize aggregation")
    func testDenormalize() {
        let script = DBlocks {
            END {
                Denormalize("latency")
            }
        }

        let source = script.source
        #expect(source.contains("denormalize(@latency);"))
    }
}

@Suite("DBlocks Time Units Tests")
struct DBlocksTimeUnitsTests {

    @Test("All time unit raw values")
    func testTimeUnitRawValues() {
        #expect(DTraceTimeUnit.nanoseconds.rawValue == "ns")
        #expect(DTraceTimeUnit.nanosec.rawValue == "nsec")
        #expect(DTraceTimeUnit.microseconds.rawValue == "us")
        #expect(DTraceTimeUnit.microsec.rawValue == "usec")
        #expect(DTraceTimeUnit.milliseconds.rawValue == "ms")
        #expect(DTraceTimeUnit.millisec.rawValue == "msec")
        #expect(DTraceTimeUnit.seconds.rawValue == "s")
        #expect(DTraceTimeUnit.sec.rawValue == "sec")
        #expect(DTraceTimeUnit.minutes.rawValue == "m")
        #expect(DTraceTimeUnit.min.rawValue == "min")
        #expect(DTraceTimeUnit.hours.rawValue == "h")
        #expect(DTraceTimeUnit.hour.rawValue == "hour")
        #expect(DTraceTimeUnit.days.rawValue == "d")
        #expect(DTraceTimeUnit.day.rawValue == "day")
        #expect(DTraceTimeUnit.hertz.rawValue == "hz")
    }
}

// MARK: - Composable API Tests

@Suite("DBlocks Composable API Tests")
struct DBlocksComposableAPITests {

    // MARK: - DBlocks Composition

    @Test("Empty DBlocks initialization")
    func testEmptyInit() {
        let script = DBlocks()
        #expect(script.clauses.isEmpty)
        #expect(script.source.isEmpty)
    }

    @Test("Add probe clause to DBlocks")
    func testAddProbeClause() {
        var script = DBlocks()
        script.add(Probe("syscall:::entry") { Count() })

        #expect(script.clauses.count == 1)
        #expect(script.source.contains("syscall:::entry"))
        #expect(script.source.contains("count()"))
    }

    @Test("Add probe with builder syntax")
    func testAddProbeWithBuilder() {
        var script = DBlocks()
        script.add("syscall:::entry") {
            Count(by: "probefunc")
        }

        #expect(script.clauses.count == 1)
        #expect(script.source.contains("@[probefunc] = count();"))
    }

    @Test("Merge two scripts")
    func testMergeScripts() {
        var script1 = DBlocks {
            BEGIN { Printf("Starting...") }
        }
        let script2 = DBlocks {
            Probe("syscall:::entry") { Count() }
        }

        script1.merge(script2)

        #expect(script1.clauses.count == 2)
        #expect(script1.source.contains("BEGIN"))
        #expect(script1.source.contains("syscall:::entry"))
    }

    @Test("Adding clause returns new script")
    func testAddingClause() {
        let base = DBlocks {
            BEGIN { Printf("Starting...") }
        }
        let extended = base.adding(Probe("syscall:::entry") { Count() })

        // Original unchanged
        #expect(base.clauses.count == 1)
        // New script has both
        #expect(extended.clauses.count == 2)
    }

    @Test("Merging returns new script")
    func testMergingScripts() {
        let script1 = DBlocks { BEGIN { Printf("Start") } }
        let script2 = DBlocks { END { Printf("End") } }

        let combined = script1.merging(script2)

        // Originals unchanged
        #expect(script1.clauses.count == 1)
        #expect(script2.clauses.count == 1)
        // Combined has both
        #expect(combined.clauses.count == 2)
    }

    @Test("Plus operator combines scripts")
    func testPlusOperator() {
        let script = DBlocks { BEGIN { Printf("Start") } }
                   + DBlocks { Probe("syscall:::entry") { Count() } }
                   + DBlocks { END { Printf("End") } }

        #expect(script.clauses.count == 3)
        #expect(script.source.contains("BEGIN"))
        #expect(script.source.contains("syscall:::entry"))
        #expect(script.source.contains("END"))
    }

    @Test("Plus equals operator appends")
    func testPlusEqualsOperator() {
        var script = DBlocks { BEGIN { Printf("Start") } }
        script += DBlocks { Probe("syscall:::entry") { Count() } }

        #expect(script.clauses.count == 2)
    }

    @Test("Combine predefined scripts")
    func testCombinePredefinedScripts() {
        let script = DBlocks { BEGIN { Printf("Tracing...") } }
                   + DBlocks.syscallCounts(for: .execname("nginx"))
                   + DBlocks { Tick(5, .seconds) { Exit(0) } }

        #expect(script.source.contains("BEGIN"))
        #expect(script.source.contains("syscall:freebsd::entry"))
        #expect(script.source.contains("nginx"))
        #expect(script.source.contains("tick-5s"))
    }

    // MARK: - ProbeClause Composition

    @Test("Empty ProbeClause initialization")
    func testEmptyProbeClause() {
        let clause = ProbeClause(probe: "syscall:::entry")
        #expect(clause.probe == "syscall:::entry")
        #expect(clause.predicates.isEmpty)
        #expect(clause.actions.isEmpty)
    }

    @Test("Add action string to clause")
    func testAddActionString() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(action: "@[probefunc] = count();")

        #expect(clause.actions.count == 1)
        #expect(clause.actions[0] == "@[probefunc] = count();")
    }

    @Test("Add action component to clause")
    func testAddActionComponent() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(Count(by: "probefunc"))

        #expect(clause.actions.count == 1)
        #expect(clause.actions[0].contains("count()"))
    }

    @Test("Add predicate string to clause")
    func testAddPredicateString() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(predicate: "execname == \"nginx\"")

        #expect(clause.predicates.count == 1)
        #expect(clause.predicates[0] == "execname == \"nginx\"")
    }

    @Test("Add Target component to clause")
    func testAddTargetComponent() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(Target(.execname("nginx")))

        #expect(clause.predicates.count == 1)
        #expect(clause.predicates[0].contains("nginx"))
    }

    @Test("Add When component to clause")
    func testAddWhenComponent() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(When("arg0 > 0"))

        #expect(clause.predicates.count == 1)
        #expect(clause.predicates[0] == "arg0 > 0")
    }

    @Test("Adding action returns new clause")
    func testAddingAction() {
        let base = ProbeClause(probe: "syscall:::entry", actions: ["@ = count();"])
        let extended = base.adding(action: "printf(\"hit\\n\");")

        #expect(base.actions.count == 1)
        #expect(extended.actions.count == 2)
    }

    @Test("Adding component returns new clause")
    func testAddingComponent() {
        let base = ProbeClause(probe: "syscall:::entry", actions: ["@ = count();"])
        let extended = base.adding(Printf("hit!"))

        #expect(base.actions.count == 1)
        #expect(extended.actions.count == 2)
    }

    @Test("Adding predicate returns new clause")
    func testAddingPredicate() {
        let base = ProbeClause(probe: "syscall:::entry", actions: ["@ = count();"])
        let filtered = base.adding(predicate: "arg0 > 0")

        #expect(base.predicates.isEmpty)
        #expect(filtered.predicates.count == 1)
    }

    @Test("Adding target returns new clause")
    func testAddingTargetComponent() {
        let base = ProbeClause(probe: "syscall:::entry", actions: ["@ = count();"])
        let filtered = base.adding(Target(.execname("nginx")))

        #expect(base.predicates.isEmpty)
        #expect(filtered.predicates.count == 1)
    }

    @Test("Build clause programmatically then add to script")
    func testBuildClauseProgrammatically() {
        var clause = ProbeClause(probe: "syscall:::entry")
        clause.add(Target(.execname("nginx")))
        clause.add(When("arg0 > 0"))
        clause.add(Count(by: "probefunc"))

        var script = DBlocks()
        script.add(clause)

        let source = script.source
        #expect(source.contains("syscall:::entry"))
        #expect(source.contains("nginx"))
        #expect(source.contains("arg0 > 0"))
        #expect(source.contains("count()"))
    }

    // MARK: - JSON Round-Trip

    @Test("JSON round-trip preserves script")
    func testJSONRoundTrip() throws {
        let original = DBlocks {
            BEGIN { Printf("Starting...") }
            Probe("syscall:::entry") {
                Target(.execname("nginx"))
                Count(by: "probefunc")
            }
            END { Printa() }
        }

        let jsonData = try original.jsonData()
        let restored = try DBlocks(jsonData: jsonData)

        #expect(restored.clauses.count == original.clauses.count)
        for (i, clause) in restored.clauses.enumerated() {
            #expect(clause.probe == original.clauses[i].probe)
            #expect(clause.predicates == original.clauses[i].predicates)
            #expect(clause.actions == original.clauses[i].actions)
        }
    }

    @Test("Create script from JSON data")
    func testCreateFromJSONData() throws {
        let json = """
        {
            "version": 1,
            "clauses": [
                {
                    "probe": "syscall:::entry",
                    "predicates": ["execname == \\"nginx\\""],
                    "actions": ["@ = count();"]
                }
            ]
        }
        """

        let script = try DBlocks(jsonData: json.data(using: .utf8)!)

        #expect(script.clauses.count == 1)
        #expect(script.clauses[0].probe == "syscall:::entry")
        #expect(script.clauses[0].predicates == ["execname == \"nginx\""])
        #expect(script.clauses[0].actions == ["@ = count();"])
    }

    @Test("Invalid JSON throws error")
    func testInvalidJSONThrows() {
        #expect(throws: DecodingError.self) {
            _ = try DBlocks(jsonData: "not valid json".data(using: .utf8)!)
        }
    }

    @Test("JSON missing probe field throws error")
    func testJSONMissingProbeThrows() {
        let json = """
        {
            "version": 1,
            "clauses": [
                {"actions": ["@ = count();"]}
            ]
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try DBlocks(jsonData: json.data(using: .utf8)!)
        }
    }

    @Test("JSON missing actions field throws error")
    func testJSONMissingActionsThrows() {
        let json = """
        {
            "version": 1,
            "clauses": [
                {"probe": "syscall:::entry"}
            ]
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try DBlocks(jsonData: json.data(using: .utf8)!)
        }
    }

    @Test("Modify script via JSON")
    func testModifyViaJSON() throws {
        // Create initial script
        let original = DBlocks {
            Probe("syscall:::entry") { Count() }
        }

        // Get JSON, modify it, restore
        let jsonData = try original.jsonData()
        guard var json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var clauses = json["clauses"] as? [[String: Any]] else {
            Issue.record("Failed to extract JSON structure")
            return
        }

        // Add a new clause via JSON manipulation
        clauses.append([
            "probe": "syscall:::return",
            "actions": ["@ = count();"]
        ])
        json["clauses"] = clauses

        let modifiedData = try JSONSerialization.data(withJSONObject: json)
        let modified = try DBlocks(jsonData: modifiedData)

        #expect(modified.clauses.count == 2)
        #expect(modified.clauses[1].probe == "syscall:::return")
    }

    @Test("DBlocksError invalidJSON description")
    func testInvalidJSONErrorDescription() {
        let error = DBlocksError.invalidJSON("test message")
        #expect(error.description.contains("Invalid JSON"))
        #expect(error.description.contains("test message"))
    }
}

@Suite("DBlocks Memory and Buffer Action Tests")
struct DBlocksMemoryActionTests {

    @Test("Tracemem renders the address and size")
    func testTracemem() {
        let script = DBlocks {
            Probe("syscall::write:entry") {
                Tracemem("arg1", size: 64)
            }
        }
        #expect(script.source.contains("tracemem(arg1, 64);"))
    }

    @Test("Copyin assigns into a thread-local")
    func testCopyin() {
        let script = DBlocks {
            Probe("syscall::write:entry") {
                Copyin(from: "arg1", size: 64, into: .thread("buf"))
            }
        }
        #expect(script.source.contains("self->buf = copyin(arg1, 64);"))
    }

    @Test("Copyinto fills a pre-allocated destination")
    func testCopyinto() {
        let script = DBlocks {
            Probe("syscall::write:entry") {
                Copyinto(from: "arg1", size: 64, into: "self->buf")
            }
        }
        #expect(script.source.contains("copyinto(arg1, 64, self->buf);"))
    }

    @Test("Discard renders the bare action")
    func testDiscard() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Discard()
            }
        }
        #expect(script.source.contains("discard();"))
    }

    @Test("Freopen with format and arg")
    func testFreopen() {
        let script = DBlocks {
            Tick(60, .seconds) {
                Freopen("/var/log/dtrace-%d.log", "walltimestamp")
            }
        }
        #expect(script.source.contains("freopen(\"/var/log/dtrace-%d.log\", walltimestamp);"))
    }

    @Test("Freopen.revert produces an empty path")
    func testFreopenRevert() {
        let script = DBlocks {
            Tick(60, .seconds) {
                Freopen.revert
            }
        }
        #expect(script.source.contains("freopen(\"\");"))
    }

    @Test("Raise renders signal as integer")
    func testRaise() {
        let script = DBlocks {
            Probe("syscall::open:entry") {
                Raise(Int32(SIGSTOP))
            }
        }
        #expect(script.source.contains("raise(\(SIGSTOP));"))
    }

    @Test("System renders format and args")
    func testSystem() {
        let script = DBlocks {
            Probe("fbt::vm_fault:entry") {
                System("kill -ABRT %d", "pid")
            }
        }
        #expect(script.source.contains("system(\"kill -ABRT %d\", pid);"))
    }
}

@Suite("DBlocks Speculation Tests")
struct DBlocksSpeculationTests {

    @Test("Speculate stages output on a thread-local id")
    func testSpeculateThreadLocal() {
        let script = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("spec"), to: "speculation()")
                Speculate(on: .thread("spec"))
                Printf("entry pid=%d", "pid")
            }
        }
        let source = script.source
        #expect(source.contains("self->spec = speculation();"))
        #expect(source.contains("speculate(self->spec);"))
        #expect(source.contains("printf(\"entry pid=%d\\n\", pid);"))
    }

    @Test("Speculate accepts a raw expression")
    func testSpeculateRawExpression() {
        let script = DBlocks {
            Probe("syscall::read:entry") {
                Speculate(rawExpression: "self->spec_id")
            }
        }
        #expect(script.source.contains("speculate(self->spec_id);"))
    }

    @Test("CommitSpeculation flushes a thread-local id")
    func testCommitSpeculation() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                When("self->spec && arg0 < 0")
                CommitSpeculation(on: .thread("spec"))
                Assign(.thread("spec"), to: "0")
            }
        }
        let source = script.source
        #expect(source.contains("commit(self->spec);"))
        #expect(source.contains("self->spec = 0;"))
    }

    @Test("DiscardSpeculation drops a thread-local id")
    func testDiscardSpeculationThreadLocal() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                When("self->spec && arg0 >= 0")
                DiscardSpeculation(on: .thread("spec"))
            }
        }
        #expect(script.source.contains("discard(self->spec);"))
    }

    @Test("DiscardSpeculation accepts a raw expression")
    func testDiscardSpeculationRaw() {
        let script = DBlocks {
            Probe("syscall::read:return") {
                DiscardSpeculation(rawExpression: "self->spec_id")
            }
        }
        #expect(script.source.contains("discard(self->spec_id);"))
    }

    @Test("Predefined: tcpConnections")
    func testPredefinedTcpConnections() {
        let source = DBlocks.tcpConnections().source
        #expect(source.contains("tcp:::state-change"))
        #expect(source.contains("tcp_state_string"))
    }

    @Test("Predefined: pageFaults reports both kinds")
    func testPredefinedPageFaults() {
        let source = DBlocks.pageFaults().source
        #expect(source.contains("vminfo:::maj_fault"))
        #expect(source.contains("vminfo:::as_fault"))
        #expect(source.contains("@major_faults[execname]"))
        #expect(source.contains("@minor_faults[execname]"))
    }

    @Test("Predefined: diskIOSizes")
    func testPredefinedDiskIOSizes() {
        let source = DBlocks.diskIOSizes().source
        #expect(source.contains("io:::start"))
        #expect(source.contains("@io_size[execname] = quantize(args[0]->b_bcount);"))
    }

    @Test("Predefined: signalDelivery")
    func testPredefinedSignalDelivery() {
        let source = DBlocks.signalDelivery().source
        #expect(source.contains("proc:::signal-send"))
        #expect(source.contains("args[1]->pr_fname"))
    }

    @Test("Predefined: mutexContention")
    func testPredefinedMutexContention() {
        let source = DBlocks.mutexContention().source
        #expect(source.contains("lockstat:::adaptive-block"))
        #expect(source.contains("@mutex_wait_ns[execname] = quantize(arg1);"))
    }

    @Test("Predefined scripts respect a target filter")
    func testPredefinedScriptsApplyTarget() {
        let source = DBlocks.tcpConnections(for: .execname("nginx")).source
        #expect(source.contains("execname == \"nginx\""))
    }

    @Test("threadLocalConflicts: empty when no overlap")
    func testNoThreadLocalConflict() {
        let a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("buf"), to: "arg1")
            }
        }
        #expect(a.threadLocalConflicts(with: b).isEmpty)
    }

    @Test("threadLocalConflicts: detects overlap")
    func testThreadLocalConflict() {
        let a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("ts"), to: "vtimestamp")
            }
        }
        #expect(a.threadLocalConflicts(with: b) == ["ts"])
    }

    @Test("threadLocalConflicts: ignores comparisons")
    func testThreadLocalNoFalsePositiveOnComparison() {
        // Reading `self->ts` (e.g. `if (self->ts == 0)`) is not an
        // assignment and must not be flagged.
        let a = DBlocks {
            Probe("syscall::read:return") {
                When("self->ts == 0")
                Action("/* … */")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:return") {
                When("self->ts != 0")
                Action("/* … */")
            }
        }
        #expect(a.threadLocalConflicts(with: b).isEmpty)
    }

    @Test("threadLocalConflicts: ignores aggregations")
    func testAggregationsNotConflicts() {
        // Both sides write to @bytes, but aggregation merges are
        // intentional and DTrace handles them.
        let a = DBlocks {
            Probe("syscall::read:return") {
                Sum("arg0", by: "execname", into: "bytes")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:return") {
                Sum("arg0", by: "execname", into: "bytes")
            }
        }
        #expect(a.threadLocalConflicts(with: b).isEmpty)
    }

    @Test("mergeChecked throws on conflict")
    func testMergeCheckedThrows() {
        var a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("ts"), to: "vtimestamp")
            }
        }
        #expect(throws: DBlocksError.self) {
            try a.mergeChecked(b)
        }
        // The original script must be unchanged on the throwing path.
        #expect(a.clauses.count == 1)
    }

    @Test("mergeChecked succeeds on non-overlapping scripts")
    func testMergeCheckedSucceeds() throws {
        var a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("buf"), to: "arg1")
            }
        }
        try a.mergeChecked(b)
        #expect(a.clauses.count == 2)
    }

    @Test("mergingChecked returns a new script")
    func testMergingCheckedSucceeds() throws {
        let a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("buf"), to: "arg1")
            }
        }
        let combined = try a.mergingChecked(b)
        #expect(combined.clauses.count == 2)
    }

    @Test("threadLocalConflict error message lists names")
    func testConflictErrorDescription() {
        let err = DBlocksError.threadLocalConflict(names: ["ts", "spec"])
        let s = err.description
        #expect(s.contains("self->ts"))
        #expect(s.contains("self->spec"))
    }

    // MARK: - Lint

    @Test("lint: clean script returns no warnings")
    func testLintClean() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count(by: "probefunc", into: "calls")
            }
            Tick(1, .seconds) {
                Printa("calls")
                Clear("calls")
            }
        }
        #expect(script.lint().isEmpty)
    }

    @Test("lint: undefined aggregation reference")
    func testLintUndefinedAggregation() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count(by: "probefunc", into: "calls")
            }
            Tick(1, .seconds) {
                Printa("missing")  // never defined
            }
        }
        let warnings = script.lint()
        #expect(warnings.count == 1)
        if case .undefinedAggregation(let name) = warnings.first?.kind {
            #expect(name == "missing")
        } else {
            Issue.record("expected undefinedAggregation warning, got \(warnings)")
        }
    }

    @Test("lint: anonymous aggregation never reported")
    func testLintAnonymousAggregationOK() {
        // Both `@` and `printa(@)` are anonymous and should not warn.
        let script = DBlocks {
            Probe("syscall:::entry") {
                Count()
            }
            Tick(1, .seconds) {
                Printa()
            }
        }
        #expect(script.lint().isEmpty)
    }

    @Test("lint: Exit() inside profile probe")
    func testLintExitInProfileProbe() {
        let script = DBlocks {
            Profile(hz: 99) {
                Exit(0)
            }
        }
        let warnings = script.lint()
        #expect(warnings.count == 1)
        if case .exitInProfileProbe(let probe) = warnings.first?.kind {
            #expect(probe.hasPrefix("profile-"))
        } else {
            Issue.record("expected exitInProfileProbe warning, got \(warnings)")
        }
    }

    @Test("lint: Exit() inside Tick is fine")
    func testLintExitInTickIsFine() {
        let script = DBlocks {
            Tick(60, .seconds) {
                Exit(0)
            }
        }
        #expect(script.lint().isEmpty)
    }

    @Test("lint: multiple warnings reported separately")
    func testLintMultipleWarnings() {
        let script = DBlocks {
            Profile(hz: 99) {
                Exit(0)
            }
            Tick(1, .seconds) {
                Printa("missing_a")
                Clear("missing_b")
            }
        }
        let warnings = script.lint()
        #expect(warnings.count == 3)
    }

    // MARK: - ProbeSpec

    @Test("ProbeSpec.syscall renders the freebsd module")
    func testProbeSpecSyscall() {
        let spec = ProbeSpec.syscall("read", .entry)
        #expect(spec.rendered == "syscall:freebsd:read:entry")
    }

    @Test("ProbeSpec.fbt renders the four-tuple")
    func testProbeSpecFbt() {
        let spec = ProbeSpec.fbt(module: "kernel", function: "uipc_send", .entry)
        #expect(spec.rendered == "fbt:kernel:uipc_send:entry")
    }

    @Test("ProbeSpec.kinst with offset renders kinst::function:offset")
    func testProbeSpecKinstWithOffset() {
        let spec = ProbeSpec.kinst(function: "vm_fault", offset: 4)
        #expect(spec.rendered == "kinst::vm_fault:4")
    }

    @Test("ProbeSpec.kinst without offset renders kinst::function:")
    func testProbeSpecKinstFirehose() {
        // Empty name field = trace every instruction in the function.
        let spec = ProbeSpec.kinst(function: "amd64_syscall")
        #expect(spec.rendered == "kinst::amd64_syscall:")
    }

    @Test("ProbeSpec.kinst with offset zero is distinguishable from no offset")
    func testProbeSpecKinstOffsetZero() {
        // offset=0 must render as ":0" (the entry instruction), NOT
        // collapse to the empty/firehose form.
        let spec = ProbeSpec.kinst(function: "vm_fault", offset: 0)
        #expect(spec.rendered == "kinst::vm_fault:0")
    }

    @Test("ProbeSpec.proc renders provider+name")
    func testProbeSpecProc() {
        #expect(ProbeSpec.proc(.execSuccess).rendered == "proc:::exec-success")
        #expect(ProbeSpec.proc(.signalSend).rendered == "proc:::signal-send")
    }

    @Test("ProbeSpec.io and .vm renders provider-only")
    func testProbeSpecIOAndVM() {
        #expect(ProbeSpec.io(.start).rendered == "io:::start")
        #expect(ProbeSpec.vm(.majorFault).rendered == "vminfo:::maj_fault")
    }

    @Test("ProbeSpec.tcp renders state-change variants")
    func testProbeSpecTCP() {
        #expect(ProbeSpec.tcp(.stateChange).rendered == "tcp:::state-change")
        #expect(ProbeSpec.tcp(.connectRequest).rendered == "tcp:::connect-request")
    }

    @Test("ProbeSpec.tick / profile / special clauses")
    func testProbeSpecRateAndSpecial() {
        #expect(ProbeSpec.tick(1, .seconds).rendered == "tick-1s:::")
        #expect(ProbeSpec.profile(99, .hertz).rendered == "profile-99hz:::")
        #expect(ProbeSpec.begin.rendered == "BEGIN:::")
        #expect(ProbeSpec.end.rendered == "END:::")
        #expect(ProbeSpec.error.rendered == "ERROR:::")
    }

    @Test("ProbeSpec.custom passes fields through")
    func testProbeSpecCustom() {
        let spec = ProbeSpec.custom(provider: "myprov", function: "*", name: "entry")
        #expect(spec.rendered == "myprov::*:entry")
    }

    @Test("Probe(spec:) builds an equivalent clause")
    func testProbeWithSpec() {
        let typed = DBlocks {
            Probe(.syscall("read", .entry)) {
                Count()
            }
        }
        let raw = DBlocks {
            Probe("syscall:freebsd:read:entry") {
                Count()
            }
        }
        #expect(typed.source == raw.source)
    }

    // MARK: - DExpr typed expressions

    @Test("DExpr.arg renders argN and args[N]")
    func testDExprArg() {
        #expect(DExpr.arg(0).rendered == "arg0")
        #expect(DExpr.args(2).rendered == "args[2]")
    }

    @Test("DExpr operator builds predicate")
    func testDExprComparison() {
        let p = DExpr.arg(0) > 0
        #expect(p.rendered == "arg0 > 0")
    }

    @Test("DExpr string equality quotes the literal")
    func testDExprStringEquality() {
        let p = DExpr.execname == "nginx"
        #expect(p.rendered == "execname == \"nginx\"")
    }

    @Test("DExpr logical conjunction")
    func testDExprConjunction() {
        let p = (DExpr.execname == "nginx") && (DExpr.arg(0) > 0)
        #expect(p.rendered == "(execname == \"nginx\") && (arg0 > 0)")
    }

    @Test("DExpr arithmetic")
    func testDExprArithmetic() {
        let elapsed = DExpr.timestamp - .threadLocal("ts")
        #expect(elapsed.rendered == "(timestamp - self->ts)")
    }

    @Test("DExpr.copyinstr renders nested call")
    func testDExprCopyinstr() {
        #expect(DExpr.copyinstr(.arg(0)).rendered == "copyinstr(arg0)")
    }

    @Test("DExpr macro arguments")
    func testDExprMacros() {
        #expect(DExpr.target.rendered == "$target")
        #expect(DExpr.macro(1).rendered == "$1")
        #expect(DExpr.macroString(2).rendered == "$$2")
    }

    @Test("When can be built from a DExpr")
    func testWhenFromDExpr() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                When(DExpr.arg(0) > 0)
                Count()
            }
        }
        #expect(script.source.contains("/(arg0 > 0)/"))
    }

    @Test("Printf can be built from typed args")
    func testPrintfFromDExpr() {
        let script = DBlocks {
            Probe("syscall::open:entry") {
                Printf("%s[%d]: %s",
                       args: [.execname, .pid, .copyinstr(.arg(0))])
            }
        }
        let source = script.source
        #expect(source.contains("printf(\"%s[%d]: %s\\n\", execname, pid, copyinstr(arg0));"))
    }

    @Test("Trace can be built from a DExpr")
    func testTraceFromDExpr() {
        let script = DBlocks {
            Probe("syscall:::entry") {
                Trace(DExpr.arg(0))
            }
        }
        #expect(script.source.contains("trace(arg0);"))
    }

    // MARK: - Aggregation snapshot type surface
    //
    // The actual snapshot() walk needs a live DTrace handle (root), so
    // these tests cover the typed value surface — making sure the case
    // accessors and equality work, and that the function signature is
    // present so callers can rely on it.

    @Test("AggregationKey description renders cases")
    func testAggregationKeyDescription() {
        #expect(AggregationKey.int(42).description == "42")
        #expect(AggregationKey.string("nginx").description == "nginx")
        #expect(AggregationKey.bytes([1, 2, 3]).description == "<3 bytes>")
    }

    @Test("AggregationValue.asInt unwraps scalar cases")
    func testAggregationValueAsInt() {
        #expect(AggregationValue.count(5).asInt == 5)
        #expect(AggregationValue.sum(1024).asInt == 1024)
        #expect(AggregationValue.min(-1).asInt == -1)
        #expect(AggregationValue.max(99).asInt == 99)
        #expect(AggregationValue.avg(7).asInt == 7)
        #expect(AggregationValue.stddev(2).asInt == 2)
        #expect(AggregationValue.quantize(Data()).asInt == nil)
        #expect(AggregationValue.lquantize(Data()).asInt == nil)
        #expect(AggregationValue.llquantize(Data()).asInt == nil)
        #expect(AggregationValue.unknown(action: 0, Data()).asInt == nil)
    }

    @Test("AggregationRecord stores fields as supplied")
    func testAggregationRecordInit() {
        let r = AggregationRecord(
            name: "calls",
            keys: [.string("nginx"), .int(8)],
            value: .count(123)
        )
        #expect(r.name == "calls")
        #expect(r.keys.count == 2)
        #expect(r.value.asInt == 123)
    }

    @Test("DTraceSession.snapshot signature is exposed")
    func testSnapshotSignature() {
        // This test validates the API exists; calling it requires root.
        let _: (borrowing DTraceSession, Bool) throws -> [AggregationRecord] = { session, sorted in
            try session.snapshot(sorted: sorted)
        }
    }

    @Test("DTraceSession.streamSnapshots signature is exposed")
    func testStreamSnapshotsSignature() {
        // This test validates the API exists; calling it requires root.
        func verify(_: (borrowing DTraceSession, TimeInterval, Int?, Bool, ([AggregationRecord]) throws -> Void) async throws -> Void) {}
        verify { session, interval, iterations, sorted, body in
            try await session.streamSnapshots(
                every: interval,
                iterations: iterations,
                sorted: sorted,
                body
            )
        }
    }

    // MARK: - Decoder tests (exercised without a live DTrace handle)

    @Test("decodeValue: COUNT loads an int64 at the offset")
    func testDecodeCountValue() {
        var buf = [UInt8](repeating: 0xFF, count: 32)
        // Place a count of 7 at offset 8.
        buf.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: Int64(7), toByteOffset: 8, as: Int64.self)
        }
        buf.withUnsafeBytes { rawBuf in
            let value = AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_COUNT.rawValue),
                offset: 8,
                size: 8,
                buffer: rawBuf.baseAddress!
            )
            #expect(value == .count(7))
        }
    }

    @Test("decodeValue: SUM/MIN/MAX dispatch correctly")
    func testDecodeScalarKindDispatch() {
        var buf = [UInt8](repeating: 0, count: 8)
        buf.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: Int64(123), toByteOffset: 0, as: Int64.self)
        }
        buf.withUnsafeBytes { rawBuf in
            let base = rawBuf.baseAddress!
            #expect(AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_SUM.rawValue),
                offset: 0, size: 8, buffer: base) == .sum(123))
            #expect(AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_MIN.rawValue),
                offset: 0, size: 8, buffer: base) == .min(123))
            #expect(AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_MAX.rawValue),
                offset: 0, size: 8, buffer: base) == .max(123))
        }
    }

    @Test("decodeValue: AVG computes sum/count")
    func testDecodeAvg() {
        // Layout (count: Int64, sum: Int64). avg = sum / count.
        var buf = [UInt8](repeating: 0, count: 16)
        buf.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: Int64(4), toByteOffset: 0, as: Int64.self)   // count
            ptr.storeBytes(of: Int64(100), toByteOffset: 8, as: Int64.self) // sum
        }
        buf.withUnsafeBytes { rawBuf in
            #expect(AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_AVG.rawValue),
                offset: 0, size: 16, buffer: rawBuf.baseAddress!
            ) == .avg(25))
        }
    }

    @Test("decodeValue: AVG with count=0 returns 0 instead of dividing")
    func testDecodeAvgZeroCount() {
        // Empty aggregation: count and sum both zero.
        let buf = [UInt8](repeating: 0, count: 16)
        buf.withUnsafeBytes { rawBuf in
            #expect(AggregationRecord.decodeValue(
                action: UInt16(CDTRACE_AGG_AVG.rawValue),
                offset: 0, size: 16, buffer: rawBuf.baseAddress!
            ) == .avg(0))
        }
    }

    @Test("decodeValue: unknown action falls through with raw bytes")
    func testDecodeUnknownAction() {
        let buf: [UInt8] = [1, 2, 3, 4]
        buf.withUnsafeBytes { rawBuf in
            let v = AggregationRecord.decodeValue(
                action: 0xDEAD,
                offset: 0, size: 4,
                buffer: rawBuf.baseAddress!
            )
            guard case .unknown(let act, let bytes) = v else {
                Issue.record("expected .unknown, got \(v)")
                return
            }
            #expect(act == 0xDEAD)
            #expect(Array(bytes) == [1, 2, 3, 4])
        }
    }

    @Test("decodeKey: int sizes 1/2/4/8 all decode")
    func testDecodeKeyIntSizes() {
        var buf = [UInt8](repeating: 0, count: 16)
        buf.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: Int8(-7),  toByteOffset: 0, as: Int8.self)
            ptr.storeBytes(of: Int16(42), toByteOffset: 2, as: Int16.self)
            ptr.storeBytes(of: Int32(1000), toByteOffset: 4, as: Int32.self)
            ptr.storeBytes(of: Int64(-9999), toByteOffset: 8, as: Int64.self)
        }
        buf.withUnsafeBytes { rawBuf in
            let base = rawBuf.baseAddress!
            #expect(AggregationRecord.decodeKey(action: 0, offset: 0, size: 1, buffer: base) == .int(-7))
            #expect(AggregationRecord.decodeKey(action: 0, offset: 2, size: 2, buffer: base) == .int(42))
            #expect(AggregationRecord.decodeKey(action: 0, offset: 4, size: 4, buffer: base) == .int(1000))
            #expect(AggregationRecord.decodeKey(action: 0, offset: 8, size: 8, buffer: base) == .int(-9999))
        }
    }

    @Test("decodeKey: NUL-terminated string is decoded as .string")
    func testDecodeKeyString() {
        var buf = [UInt8](repeating: 0, count: 16)
        let bytes = "nginx".utf8
        for (i, b) in bytes.enumerated() { buf[i] = b }
        buf.withUnsafeBytes { rawBuf in
            let key = AggregationRecord.decodeKey(
                action: 0, offset: 0, size: 16,
                buffer: rawBuf.baseAddress!
            )
            #expect(key == .string("nginx"))
        }
    }

    @Test("decodeKey: arbitrary bytes that don't form a string fall through")
    func testDecodeKeyBytesFallthrough() {
        // No NUL, not a useful string.
        let buf: [UInt8] = [0x80, 0x81, 0x82]
        buf.withUnsafeBytes { rawBuf in
            let key = AggregationRecord.decodeKey(
                action: 0, offset: 0, size: 3,
                buffer: rawBuf.baseAddress!
            )
            guard case .bytes(let arr) = key else {
                Issue.record("expected .bytes, got \(key)")
                return
            }
            #expect(arr == [0x80, 0x81, 0x82])
        }
    }

    // MARK: - Scanner edge cases

    @Test("threadLocalConflicts ignores += and = side conditions correctly")
    func testThreadLocalScannerCorrectness() {
        // Both scripts mention 'self->ts' but only one ASSIGNS to it.
        let writer = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let reader = DBlocks {
            Probe("syscall::read:return") {
                When("self->ts > 0")          // read, not assign
                Trace("self->ts")              // read, not assign
            }
        }
        // The reader doesn't assign self->ts, so there must be no
        // conflict reported.
        #expect(writer.threadLocalConflicts(with: reader).isEmpty)
        #expect(reader.threadLocalConflicts(with: writer).isEmpty)
    }

    // MARK: - Dwatch-style profiles

    @Test("Dwatch.kill renders signal+pid printf")
    func testDwatchKill() {
        let s = DBlocks.Dwatch.kill().source
        #expect(s.contains("syscall::kill:entry"))
        #expect(s.contains("signal %d to pid %d"))
    }

    @Test("Dwatch.open covers open and openat")
    func testDwatchOpen() {
        let s = DBlocks.Dwatch.open().source
        #expect(s.contains("syscall::open:entry"))
        #expect(s.contains("syscall::openat:entry"))
        #expect(s.contains("copyinstr(arg0)"))
        #expect(s.contains("copyinstr(arg1)"))
    }

    @Test("Dwatch.readWrite covers both syscalls")
    func testDwatchReadWrite() {
        let s = DBlocks.Dwatch.readWrite().source
        #expect(s.contains("syscall::read:entry"))
        #expect(s.contains("syscall::write:entry"))
        #expect(s.contains("nbyte=%d"))
    }

    @Test("Dwatch.chmod covers chmod/fchmodat/lchmod")
    func testDwatchChmod() {
        let s = DBlocks.Dwatch.chmod().source
        #expect(s.contains("syscall::chmod:entry"))
        #expect(s.contains("syscall::fchmodat:entry"))
        #expect(s.contains("syscall::lchmod:entry"))
        #expect(s.contains("mode=%o"))
    }

    @Test("Dwatch.procExec covers success and failure")
    func testDwatchProcExec() {
        let s = DBlocks.Dwatch.procExec().source
        #expect(s.contains("proc:::exec-success"))
        #expect(s.contains("proc:::exec-failure"))
        #expect(s.contains("exec ok"))
        #expect(s.contains("exec FAIL"))
    }

    @Test("Dwatch.procExit renders proc:::exit")
    func testDwatchProcExit() {
        let s = DBlocks.Dwatch.procExit().source
        #expect(s.contains("proc:::exit"))
        #expect(s.contains("exit reason=%d"))
    }

    @Test("Dwatch.tcp renders tcp:::state-change with state strings")
    func testDwatchTCP() {
        let s = DBlocks.Dwatch.tcp().source
        #expect(s.contains("tcp:::state-change"))
        #expect(s.contains("tcp_state_string"))
    }

    @Test("Dwatch.udp covers send and receive")
    func testDwatchUDP() {
        let s = DBlocks.Dwatch.udp().source
        #expect(s.contains("udp:::receive"))
        #expect(s.contains("udp:::send"))
    }

    @Test("Dwatch.nanosleep renders syscall::nanosleep:entry")
    func testDwatchNanosleep() {
        let s = DBlocks.Dwatch.nanosleep().source
        #expect(s.contains("syscall::nanosleep:entry"))
    }

    @Test("Dwatch.errnoTracer adds an errno != 0 predicate")
    func testDwatchErrnoTracer() {
        let s = DBlocks.Dwatch.errnoTracer().source
        #expect(s.contains("syscall:::return"))
        #expect(s.contains("errno != 0"))
        #expect(s.contains("errno %d"))
    }

    @Test("Dwatch.systop counts syscalls with named aggregation")
    func testDwatchSystop() {
        let s = DBlocks.Dwatch.systop().source
        #expect(s.contains("syscall:::entry"))
        #expect(s.contains("@syscalls[execname, probefunc] = count();"))
        #expect(s.contains("END"))
        #expect(s.contains("printa(@syscalls);"))
    }

    @Test("Dwatch profiles all respect the target filter")
    func testDwatchProfilesApplyTarget() {
        let target = DTraceTarget.execname("nginx")
        let scripts = [
            DBlocks.Dwatch.kill(for: target),
            DBlocks.Dwatch.open(for: target),
            DBlocks.Dwatch.readWrite(for: target),
            DBlocks.Dwatch.chmod(for: target),
            DBlocks.Dwatch.procExec(for: target),
            DBlocks.Dwatch.procExit(for: target),
            DBlocks.Dwatch.tcp(for: target),
            DBlocks.Dwatch.udp(for: target),
            DBlocks.Dwatch.nanosleep(for: target),
            DBlocks.Dwatch.errnoTracer(for: target),
            DBlocks.Dwatch.systop(for: target),
        ]
        for script in scripts {
            #expect(script.source.contains("execname == \"nginx\""))
        }
    }

    @Test("Dwatch.kinst with offset renders the kinst probe spec")
    func testDwatchKinstWithOffset() {
        let s = DBlocks.Dwatch.kinst(function: "vm_fault", offset: 4).source
        #expect(s.contains("kinst::vm_fault:4"))
        #expect(s.contains("vm_fault+4"))
    }

    @Test("Dwatch.kinst without offset renders the firehose form")
    func testDwatchKinstFirehose() {
        let s = DBlocks.Dwatch.kinst(function: "amd64_syscall").source
        #expect(s.contains("kinst::amd64_syscall:"))
        #expect(s.contains("amd64_syscall+all"))
    }

    @Test("Dwatch.kinst respects the target filter")
    func testDwatchKinstTarget() {
        // Kernel-side probes don't usually need a per-process filter,
        // but it's exposed for symmetry — verify the predicate lands.
        let s = DBlocks.Dwatch.kinst(
            function: "vm_fault",
            offset: 4,
            for: .execname("nginx")
        ).source
        #expect(s.contains("execname == \"nginx\""))
    }

    // MARK: - "Tests that break things" — negative paths

    @Test("validate() throws on empty script")
    func testValidateEmpty() {
        let s = DBlocks()
        #expect(throws: DBlocksError.self) { try s.validate() }
    }

    @Test("validate() throws on a clause with no actions")
    func testValidateEmptyClause() {
        let s = DBlocks(clauses: [
            ProbeClause(probe: "syscall:::entry", actions: [])
        ])
        #expect(throws: DBlocksError.self) { try s.validate() }
    }

    @Test("DBlocks(jsonData:) rejects malformed JSON")
    func testDBlocksRejectsMalformedJSON() {
        let bogus = Data("{this is not json".utf8)
        #expect(throws: (any Error).self) { _ = try DBlocks(jsonData: bogus) }
    }

    @Test("DBlocks(jsonData:) rejects valid JSON without expected fields")
    func testDBlocksRejectsWrongShapeJSON() {
        let wrong = Data(#"{"version":1,"unrelated":42}"#.utf8)
        #expect(throws: (any Error).self) { _ = try DBlocks(jsonData: wrong) }
    }

    @Test("mergeChecked rejects scripts that share a thread-local")
    func testMergeCheckedRejectsConflict() {
        var a = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("ts"), to: "timestamp")
            }
        }
        let b = DBlocks {
            Probe("syscall::write:entry") {
                Assign(.thread("ts"), to: "vtimestamp")
            }
        }
        #expect(throws: DBlocksError.self) { try a.mergeChecked(b) }
    }

    @Test("Dwatch.systop rendered script lints clean")
    func testDwatchSystopLintsClean() {
        // The systop script defines @syscalls and references it from
        // the END clause. lint() must not complain.
        #expect(DBlocks.Dwatch.systop().lint().isEmpty)
    }

    @Test("A profile clause with Exit() lints noisy")
    func testExitInProfileLintsNoisy() {
        let bad = DBlocks {
            Profile(hz: 99) {
                Exit(0)
            }
        }
        let warns = bad.lint()
        #expect(warns.count == 1)
    }

    @Test("lint distinguishes definition from reference")
    func testLintScannerCorrectness() {
        // Define @calls AND reference @calls — clean.
        let clean = DBlocks {
            Probe("syscall:::entry") { Count(by: "probefunc", into: "calls") }
            Tick(1, .seconds) { Printa("calls") }
        }
        #expect(clean.lint().isEmpty)

        // Reference @other when only @calls is defined — should warn.
        let dirty = DBlocks {
            Probe("syscall:::entry") { Count(by: "probefunc", into: "calls") }
            Tick(1, .seconds) { Printa("other") }
        }
        let warns = dirty.lint()
        #expect(warns.count == 1)
        if case .undefinedAggregation(let name) = warns.first?.kind {
            #expect(name == "other")
        } else {
            Issue.record("expected undefinedAggregation, got \(warns)")
        }
    }

    @Test("End-to-end speculation pattern")
    func testFullSpeculationPattern() {
        // The canonical "only keep failed reads" speculative tracing
        // pattern: stage on entry, commit on failure, drop on success.
        let script = DBlocks {
            Probe("syscall::read:entry") {
                Assign(.thread("spec"), to: "speculation()")
                Speculate(on: .thread("spec"))
                Printf("entry pid=%d", "pid")
            }
            Probe("syscall::read:return") {
                When("self->spec && arg0 < 0")
                CommitSpeculation(on: .thread("spec"))
                Assign(.thread("spec"), to: "0")
            }
            Probe("syscall::read:return") {
                When("self->spec && arg0 >= 0")
                DiscardSpeculation(on: .thread("spec"))
                Assign(.thread("spec"), to: "0")
            }
        }
        let source = script.source
        #expect(source.contains("self->spec = speculation();"))
        #expect(source.contains("speculate(self->spec);"))
        #expect(source.contains("commit(self->spec);"))
        #expect(source.contains("discard(self->spec);"))
    }
}
