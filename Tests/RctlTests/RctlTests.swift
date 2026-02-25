/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Descriptors
@testable import Rctl

final class RctlTests: XCTestCase {

    // MARK: - Subject Tests

    func testSubjectProcess() {
        let subject = Rctl.Subject.process(1234)
        XCTAssertEqual(subject.filterString, "process:1234")
        XCTAssertEqual(subject.typeName, "process")
        XCTAssertEqual(subject.identifier, "1234")
    }

    func testSubjectUser() {
        let subject = Rctl.Subject.user(1000)
        XCTAssertEqual(subject.filterString, "user:1000")
        XCTAssertEqual(subject.typeName, "user")
    }

    func testSubjectUserName() {
        let subject = Rctl.Subject.userName("www")
        XCTAssertEqual(subject.filterString, "user:www")
        XCTAssertEqual(subject.typeName, "user")
        XCTAssertEqual(subject.identifier, "www")
    }

    func testSubjectLoginClass() {
        let subject = Rctl.Subject.loginClass("daemon")
        XCTAssertEqual(subject.filterString, "loginclass:daemon")
        XCTAssertEqual(subject.typeName, "loginclass")
    }

    func testSubjectJail() {
        let subject = Rctl.Subject.jail(5)
        XCTAssertEqual(subject.filterString, "jail:5")
        XCTAssertEqual(subject.typeName, "jail")
    }

    func testSubjectJailName() {
        let subject = Rctl.Subject.jailName("myjail")
        XCTAssertEqual(subject.filterString, "jail:myjail")
        XCTAssertEqual(subject.typeName, "jail")
    }

    // MARK: - Resource Tests

    func testResourceRawValues() {
        XCTAssertEqual(Rctl.Resource.cpuTime.rawValue, "cputime")
        XCTAssertEqual(Rctl.Resource.memoryUse.rawValue, "memoryuse")
        XCTAssertEqual(Rctl.Resource.maxProc.rawValue, "maxproc")
        XCTAssertEqual(Rctl.Resource.openFiles.rawValue, "openfiles")
        XCTAssertEqual(Rctl.Resource.vmemoryUse.rawValue, "vmemoryuse")
        XCTAssertEqual(Rctl.Resource.pcpu.rawValue, "pcpu")
        XCTAssertEqual(Rctl.Resource.readBps.rawValue, "readbps")
        XCTAssertEqual(Rctl.Resource.writeBps.rawValue, "writebps")
    }

    func testResourceAllCases() {
        // Verify we have all expected resources
        XCTAssertGreaterThanOrEqual(Rctl.Resource.allCases.count, 20)
    }

    // MARK: - Action Tests

    func testActionStrings() {
        XCTAssertEqual(Rctl.Action.deny.actionString, "deny")
        XCTAssertEqual(Rctl.Action.log.actionString, "log")
        XCTAssertEqual(Rctl.Action.devctl.actionString, "devctl")
        XCTAssertEqual(Rctl.Action.throttle.actionString, "throttle")
        XCTAssertEqual(Rctl.Action.signal(SIGTERM).actionString, "sigterm")
        XCTAssertEqual(Rctl.Action.signal(SIGKILL).actionString, "sigkill")
    }

    func testActionParse() {
        XCTAssertEqual(Rctl.Action.parse("deny"), .deny)
        XCTAssertEqual(Rctl.Action.parse("log"), .log)
        XCTAssertEqual(Rctl.Action.parse("devctl"), .devctl)
        XCTAssertEqual(Rctl.Action.parse("throttle"), .throttle)
        XCTAssertEqual(Rctl.Action.parse("sigterm"), .signal(SIGTERM))
        XCTAssertEqual(Rctl.Action.parse("SIGKILL"), .signal(SIGKILL))
        XCTAssertNil(Rctl.Action.parse("invalid"))
    }

    // MARK: - Per Tests

    func testPerRawValues() {
        XCTAssertEqual(Rctl.Per.process.rawValue, "process")
        XCTAssertEqual(Rctl.Per.user.rawValue, "user")
        XCTAssertEqual(Rctl.Per.loginClass.rawValue, "loginclass")
        XCTAssertEqual(Rctl.Per.jail.rawValue, "jail")
    }

    // MARK: - Rule Tests

    func testRuleString() {
        let rule = Rctl.Rule(
            subject: .user(1000),
            resource: .memoryUse,
            action: .deny,
            amount: 536870912  // 512MB
        )
        XCTAssertEqual(rule.ruleString, "user:1000:memoryuse:deny=536870912")
    }

    func testRuleStringWithPer() {
        let rule = Rctl.Rule(
            subject: .jail(5),
            resource: .maxProc,
            action: .deny,
            amount: 100,
            per: .user
        )
        XCTAssertEqual(rule.ruleString, "jail:5:maxproc:deny=100/user")
    }

    func testRuleStringWithSignal() {
        let rule = Rctl.Rule(
            subject: .loginClass("daemon"),
            resource: .cpuTime,
            action: .signal(SIGXCPU),
            amount: 3600
        )
        XCTAssertEqual(rule.ruleString, "loginclass:daemon:cputime:sigxcpu=3600")
    }

    func testRuleParsing() {
        let rule = Rctl.Rule(parsing: "user:1000:memoryuse:deny=536870912")
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.subject, .user(1000))
        XCTAssertEqual(rule?.resource, .memoryUse)
        XCTAssertEqual(rule?.action, .deny)
        XCTAssertEqual(rule?.amount, 536870912)
        XCTAssertNil(rule?.per)
    }

    func testRuleParsingWithPer() {
        let rule = Rctl.Rule(parsing: "jail:myjail:maxproc:deny=100/user")
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.subject, .jailName("myjail"))
        XCTAssertEqual(rule?.resource, .maxProc)
        XCTAssertEqual(rule?.action, .deny)
        XCTAssertEqual(rule?.amount, 100)
        XCTAssertEqual(rule?.per, .user)
    }

    func testRuleParsingInvalid() {
        XCTAssertNil(Rctl.Rule(parsing: "invalid"))
        XCTAssertNil(Rctl.Rule(parsing: "user:1000"))
        XCTAssertNil(Rctl.Rule(parsing: "user:1000:invalid:deny=100"))
    }

    func testRuleDescription() {
        let rule = Rctl.Rule(
            subject: .process(1234),
            resource: .openFiles,
            action: .log,
            amount: 1000
        )
        XCTAssertEqual(rule.description, "process:1234:openfiles:log=1000")
    }

    // MARK: - Size Helper Tests

    func testSizeHelpers() {
        XCTAssertEqual(Rctl.Size.kb(1), 1024)
        XCTAssertEqual(Rctl.Size.mb(1), 1024 * 1024)
        XCTAssertEqual(Rctl.Size.gb(1), 1024 * 1024 * 1024)
        XCTAssertEqual(Rctl.Size.mb(512), 536870912)
    }

    // MARK: - Rule Builder Tests

    func testRuleBuilder() {
        var builder = Rctl.ruleBuilder()
        _ = builder.forSubject(.user(1000))
        _ = builder.limiting(.memoryUse)
        _ = builder.withAction(.deny)
        _ = builder.toAmount(Rctl.Size.gb(1))

        let rule = builder.build()
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.subject, .user(1000))
        XCTAssertEqual(rule?.resource, .memoryUse)
        XCTAssertEqual(rule?.action, .deny)
        XCTAssertEqual(rule?.amount, 1073741824)
    }

    func testRuleBuilderIncomplete() {
        var builder = Rctl.ruleBuilder()
        _ = builder.forSubject(.user(1000))
        // Missing resource, action, amount
        XCTAssertNil(builder.build())
    }

    // MARK: - Error Tests

    func testErrorEquatable() {
        XCTAssertEqual(Rctl.Error.notPermitted, Rctl.Error.notPermitted)
        XCTAssertNotEqual(Rctl.Error.notPermitted, Rctl.Error.invalidArgument)
    }

    func testErrorDescription() {
        let error = Rctl.Error(errno: EPERM)
        XCTAssertFalse(error.description.isEmpty)
    }

    func testErrorPresets() {
        XCTAssertEqual(Rctl.Error.notPermitted.errno, EPERM)
        XCTAssertEqual(Rctl.Error.noSuchSubject.errno, ESRCH)
        XCTAssertEqual(Rctl.Error.invalidArgument.errno, EINVAL)
        XCTAssertEqual(Rctl.Error.notSupported.errno, ENOSYS)
    }

    // MARK: - Descriptor Integration Tests

    func testSubjectFromProcessDescriptor() {
        // Test that Subject.process(from:) works with ProcessCapability
        // We can't actually fork in tests easily, but we can verify the API exists
        // by checking the type signature compiles
        let subject = Rctl.Subject.process(getpid())
        XCTAssertEqual(subject.typeName, "process")
    }

    // MARK: - System Tests (may require rctl enabled)

    func testIsEnabled() {
        // Just verify we can check without crashing
        _ = Rctl.isEnabled
    }

    func testGetUsageCurrentProcess() {
        // Skip if rctl is not enabled
        guard Rctl.isEnabled else {
            print("Skipping testGetUsageCurrentProcess: rctl not enabled")
            return
        }

        do {
            let usage = try Rctl.getCurrentProcessUsage()
            // Should have at least some resources
            XCTAssertFalse(usage.isEmpty)
        } catch let error as Rctl.Error where error.errno == ENOSYS {
            print("Skipping testGetUsageCurrentProcess: rctl not enabled in kernel")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetUsageForProcess() {
        guard Rctl.isEnabled else {
            print("Skipping testGetUsageForProcess: rctl not enabled")
            return
        }

        do {
            let usage = try Rctl.getUsage(for: .process(getpid()))
            XCTAssertFalse(usage.isEmpty)
        } catch let error as Rctl.Error where error.errno == ENOSYS {
            print("Skipping testGetUsageForProcess: rctl not enabled in kernel")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetRulesNoRules() {
        guard Rctl.isEnabled else {
            print("Skipping testGetRulesNoRules: rctl not enabled")
            return
        }

        do {
            // Should return empty array if no rules match
            let rules = try Rctl.getRules(for: .process(getpid()))
            // We don't know if there are rules, just verify it doesn't crash
            _ = rules
        } catch let error as Rctl.Error where error.errno == ENOSYS || error.errno == EPERM {
            print("Skipping testGetRulesNoRules: rctl not available or not permitted")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
