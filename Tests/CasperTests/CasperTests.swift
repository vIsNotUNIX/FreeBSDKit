/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import Casper

final class CasperTests: XCTestCase {

    // MARK: - CasperService Tests

    func testCasperServiceRawValues() {
        XCTAssertEqual(CasperService.dns.rawValue, "system.dns")
        XCTAssertEqual(CasperService.sysctl.rawValue, "system.sysctl")
        XCTAssertEqual(CasperService.pwd.rawValue, "system.pwd")
        XCTAssertEqual(CasperService.grp.rawValue, "system.grp")
        XCTAssertEqual(CasperService.fileargs.rawValue, "system.fileargs")
        XCTAssertEqual(CasperService.net.rawValue, "system.net")
        XCTAssertEqual(CasperService.netdb.rawValue, "system.netdb")
        XCTAssertEqual(CasperService.syslog.rawValue, "system.syslog")
    }

    func testCasperServiceHashable() {
        let services: Set<CasperService> = [.dns, .sysctl, .pwd]
        XCTAssertTrue(services.contains(.dns))
        XCTAssertTrue(services.contains(.sysctl))
        XCTAssertTrue(services.contains(.pwd))
        XCTAssertFalse(services.contains(.grp))
    }

    // MARK: - CasperError Tests

    func testCasperErrorEquatable() {
        XCTAssertEqual(CasperError.initFailed, CasperError.initFailed)
        XCTAssertEqual(
            CasperError.serviceOpenFailed(service: "dns"),
            CasperError.serviceOpenFailed(service: "dns")
        )
        XCTAssertNotEqual(
            CasperError.serviceOpenFailed(service: "dns"),
            CasperError.serviceOpenFailed(service: "sysctl")
        )
    }

    // MARK: - CasperSysctl AccessFlags Tests

    func testSysctlAccessFlags() {
        let read = CasperSysctl.AccessFlags.read
        let write = CasperSysctl.AccessFlags.write
        let readWrite = CasperSysctl.AccessFlags.readWrite

        XCTAssertTrue(readWrite.contains(read))
        XCTAssertTrue(readWrite.contains(write))

        let combined: CasperSysctl.AccessFlags = [.read, .write]
        XCTAssertEqual(combined, readWrite)
    }

    // MARK: - CasperSyslog Tests

    func testSyslogOptions() {
        let options: CasperSyslog.Options = [.pid, .cons]
        XCTAssertTrue(options.contains(.pid))
        XCTAssertTrue(options.contains(.cons))
        XCTAssertFalse(options.contains(.perror))
    }

    func testSyslogPriority() {
        XCTAssertEqual(CasperSyslog.Priority.emerg.rawValue, 0)
        XCTAssertEqual(CasperSyslog.Priority.debug.rawValue, 7)
    }

    func testSyslogFacility() {
        XCTAssertEqual(CasperSyslog.Facility.daemon.rawValue, 24)
        XCTAssertEqual(CasperSyslog.Facility.local0.rawValue, 128)
    }

    // MARK: - CasperDNS LookupType Tests

    func testDNSLookupTypeRawValues() {
        XCTAssertEqual(CasperDNS.LookupType.nameToAddress.rawValue, "NAME2ADDR")
        XCTAssertEqual(CasperDNS.LookupType.addressToName.rawValue, "ADDR2NAME")
    }

    // MARK: - CasperPwd Tests

    func testPwdCommandRawValues() {
        XCTAssertEqual(CasperPwd.Command.getpwnam.rawValue, "getpwnam")
        XCTAssertEqual(CasperPwd.Command.getpwuid.rawValue, "getpwuid")
        XCTAssertEqual(CasperPwd.Command.getpwnam_r.rawValue, "getpwnam_r")
    }

    func testPwdFieldRawValues() {
        XCTAssertEqual(CasperPwd.Field.name.rawValue, "pw_name")
        XCTAssertEqual(CasperPwd.Field.uid.rawValue, "pw_uid")
        XCTAssertEqual(CasperPwd.Field.shell.rawValue, "pw_shell")
    }

    // MARK: - CasperGrp Tests

    func testGrpCommandRawValues() {
        XCTAssertEqual(CasperGrp.Command.getgrnam.rawValue, "getgrnam")
        XCTAssertEqual(CasperGrp.Command.getgrgid.rawValue, "getgrgid")
    }

    func testGrpFieldRawValues() {
        XCTAssertEqual(CasperGrp.Field.name.rawValue, "gr_name")
        XCTAssertEqual(CasperGrp.Field.gid.rawValue, "gr_gid")
        XCTAssertEqual(CasperGrp.Field.mem.rawValue, "gr_mem")
    }

    // MARK: - CasperFileargs Tests

    func testFileargsOperations() {
        let open = CasperFileargs.Operations.open
        let lstat = CasperFileargs.Operations.lstat
        let realpath = CasperFileargs.Operations.realpath
        let all = CasperFileargs.Operations.all

        XCTAssertTrue(all.contains(open))
        XCTAssertTrue(all.contains(lstat))
        XCTAssertTrue(all.contains(realpath))

        let combined: CasperFileargs.Operations = [.open, .lstat]
        XCTAssertTrue(combined.contains(.open))
        XCTAssertTrue(combined.contains(.lstat))
        XCTAssertFalse(combined.contains(.realpath))
    }

    // MARK: - CasperNet Tests

    func testNetModeFlags() {
        let mode: CasperNet.Mode = [.nameToAddress, .connect]
        XCTAssertTrue(mode.contains(.nameToAddress))
        XCTAssertTrue(mode.contains(.connect))
        XCTAssertFalse(mode.contains(.bind))

        let allDNS = CasperNet.Mode.allDNS
        XCTAssertTrue(allDNS.contains(.addressToName))
        XCTAssertTrue(allDNS.contains(.nameToAddress))

        let allSocket = CasperNet.Mode.allSocket
        XCTAssertTrue(allSocket.contains(.connect))
        XCTAssertTrue(allSocket.contains(.bind))
    }

    // MARK: - Integration Tests (require Casper daemon)
    // These tests are skipped if Casper is not available

    func testCasperChannelCreate() throws {
        // This test requires the Casper daemon to be running
        // Skip if not available
        do {
            let casper = try CasperChannel.create()
            // If we get here, Casper is available
            _ = casper // Use it to avoid warning
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        }
    }

    func testCasperDNSService() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)
            _ = dns
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperSysctlService() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Try to read hostname
            let hostname = try sysctl.getString("kern.hostname")
            XCTAssertFalse(hostname.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperPwdService() throws {
        do {
            let casper = try CasperChannel.create()
            let pwd = try CasperPwd(casper: casper)

            // Try to look up root
            if let root = pwd.getpwnam("root") {
                XCTAssertEqual(root.uid, 0)
                XCTAssertEqual(root.name, "root")
            } else {
                XCTFail("Could not find root user")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Password service not available")
        }
    }

    func testCasperGrpService() throws {
        do {
            let casper = try CasperChannel.create()
            let grp = try CasperGrp(casper: casper)

            // Try to look up wheel
            if let wheel = grp.getgrnam("wheel") {
                XCTAssertEqual(wheel.gid, 0)
                XCTAssertEqual(wheel.name, "wheel")
            } else {
                XCTFail("Could not find wheel group")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Group service not available")
        }
    }

    func testCasperNetService() throws {
        do {
            let casper = try CasperChannel.create()
            let net = try CasperNet(casper: casper)

            // Try to resolve localhost
            let addresses = try net.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Network service not available")
        }
    }

    func testCasperNetdbService() throws {
        do {
            let casper = try CasperChannel.create()
            let netdb = try CasperNetdb(casper: casper)

            // Try to look up TCP protocol
            if let tcp = netdb.getprotobyname("tcp") {
                XCTAssertEqual(tcp.name, "tcp")
                XCTAssertEqual(tcp.proto, 6) // TCP protocol number
            } else {
                XCTFail("Could not find TCP protocol")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper daemon not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Netdb service not available")
        }
    }
}
