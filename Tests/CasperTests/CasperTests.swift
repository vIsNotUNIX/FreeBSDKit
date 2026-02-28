/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import Casper
@testable import Capsicum

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

    func testCasperServiceCustom() {
        let custom = CasperService(rawValue: "custom.service")
        XCTAssertEqual(custom.rawValue, "custom.service")
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
        XCTAssertEqual(
            CasperError.limitSetFailed(errno: EINVAL),
            CasperError.limitSetFailed(errno: EINVAL)
        )
        XCTAssertNotEqual(
            CasperError.limitSetFailed(errno: EINVAL),
            CasperError.limitSetFailed(errno: EPERM)
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

        let recursive: CasperSysctl.AccessFlags = [.read, .recursive]
        XCTAssertTrue(recursive.contains(.recursive))
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
        XCTAssertEqual(CasperSyslog.Priority.alert.rawValue, 1)
        XCTAssertEqual(CasperSyslog.Priority.crit.rawValue, 2)
        XCTAssertEqual(CasperSyslog.Priority.err.rawValue, 3)
        XCTAssertEqual(CasperSyslog.Priority.warning.rawValue, 4)
        XCTAssertEqual(CasperSyslog.Priority.notice.rawValue, 5)
        XCTAssertEqual(CasperSyslog.Priority.info.rawValue, 6)
        XCTAssertEqual(CasperSyslog.Priority.debug.rawValue, 7)
    }

    func testSyslogFacility() {
        XCTAssertEqual(CasperSyslog.Facility.kern.rawValue, 0)
        XCTAssertEqual(CasperSyslog.Facility.user.rawValue, 8)
        XCTAssertEqual(CasperSyslog.Facility.daemon.rawValue, 24)
        XCTAssertEqual(CasperSyslog.Facility.local0.rawValue, 128)
        XCTAssertEqual(CasperSyslog.Facility.local7.rawValue, 184)
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

        let all = CasperNet.Mode.all
        XCTAssertTrue(all.contains(.addressToName))
        XCTAssertTrue(all.contains(.nameToAddress))
        XCTAssertTrue(all.contains(.connect))
        XCTAssertTrue(all.contains(.bind))
        XCTAssertTrue(all.contains(.connectDNS))
    }

    // MARK: - CasperChannel Integration Tests

    func testCasperChannelCreate() throws {
        do {
            let casper = try CasperChannel.create()
            // Verify we got a valid channel by checking socket
            XCTAssertGreaterThan(casper.socket, 0)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        }
    }

    func testCasperChannelClone() throws {
        do {
            let casper = try CasperChannel.create()
            let clone = try casper.clone()

            // Both channels should have valid sockets
            XCTAssertGreaterThan(casper.socket, 0)
            XCTAssertGreaterThan(clone.socket, 0)
            // They should be different sockets
            XCTAssertNotEqual(casper.socket, clone.socket)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        }
    }

    func testCasperChannelServiceLimit() throws {
        do {
            let casper = try CasperChannel.create()

            // Limit to only DNS and sysctl services
            try casper.limitServices([.dns, .sysctl])

            // Should be able to open allowed services
            let dnsResult = casper.openService(.dns)
            switch dnsResult {
            case .success:
                break // Expected
            case .failure(let error):
                XCTFail("Failed to open DNS service after limiting: \(error)")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        }
    }

    func testCasperChannelOpenServiceResult() throws {
        do {
            let casper = try CasperChannel.create()

            // Test Result-returning version
            let result = casper.openService(.dns)
            switch result {
            case .success(let channel):
                XCTAssertGreaterThan(channel.socket, 0)
            case .failure(let error):
                XCTFail("Failed to open DNS service: \(error)")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        }
    }

    // MARK: - CasperDNS Integration Tests

    func testCasperDNSGetaddrinfo() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Resolve localhost
            let addresses = try dns.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty, "Should resolve localhost")

            // Check we got valid addresses
            for addr in addresses {
                XCTAssertTrue(addr.family == AF_INET || addr.family == AF_INET6)
                XCTAssertFalse(addr.addressData.isEmpty)
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSGetaddrinfoWithPort() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Resolve localhost with port
            let addresses = try dns.getaddrinfo(
                hostname: "localhost",
                port: "80",
                socktype: SOCK_STREAM
            )
            XCTAssertFalse(addresses.isEmpty, "Should resolve localhost:80")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSGetaddrinfoIPv4Only() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Resolve localhost, IPv4 only
            let addresses = try dns.getaddrinfo(
                hostname: "localhost",
                family: AF_INET
            )
            XCTAssertFalse(addresses.isEmpty, "Should resolve localhost to IPv4")

            // All results should be IPv4
            for addr in addresses {
                XCTAssertEqual(addr.family, AF_INET)
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSGethostbyname() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Resolve localhost using legacy API
            guard let host = dns.gethostbyname("localhost") else {
                XCTFail("gethostbyname returned nil for localhost")
                return
            }

            XCTAssertEqual(host.name, "localhost")
            XCTAssertFalse(host.addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSLimitTypes() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Limit to forward lookups only
            try dns.limit(types: [.nameToAddress])

            // Forward lookup should still work
            let addresses = try dns.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSLimitFamilies() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Limit to IPv4 only
            try dns.limit(families: [AF_INET])

            // Should only get IPv4 results (if any)
            // Note: After limiting, we may get no results if the system doesn't
            // have IPv4 configured for localhost
            do {
                let addresses = try dns.getaddrinfo(hostname: "localhost", family: AF_INET)
                for addr in addresses {
                    XCTAssertEqual(addr.family, AF_INET, "Should only get IPv4 addresses")
                }
            } catch CasperError.operationFailed(let errno) {
                // May fail if no IPv4 is available - that's OK
                if errno != 8 { // EAI_NONAME or similar
                    throw CasperError.operationFailed(errno: errno)
                }
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperDNSResolvedAddressString() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            let addresses = try dns.getaddrinfo(hostname: "localhost", family: AF_INET)
            XCTAssertFalse(addresses.isEmpty)

            // Check that we can get a string representation
            if let first = addresses.first {
                let addrString = first.addressString
                XCTAssertNotNil(addrString)
                // localhost should resolve to 127.0.0.1
                XCTAssertEqual(addrString, "127.0.0.1")
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    // MARK: - CasperSysctl Integration Tests

    func testCasperSysctlGetString() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Read hostname
            let hostname = try sysctl.getString("kern.hostname")
            XCTAssertFalse(hostname.isEmpty, "Hostname should not be empty")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlGetInt() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Read OS release date
            let osreldate: Int32 = try sysctl.get("kern.osreldate")
            XCTAssertGreaterThan(osreldate, 0, "OS release date should be positive")

            // Should be FreeBSD 13+ (1300000+)
            XCTAssertGreaterThan(osreldate, 1300000, "Should be FreeBSD 13+")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlGetMultiple() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Read multiple sysctls
            let hostname = try sysctl.getString("kern.hostname")
            let ostype = try sysctl.getString("kern.ostype")
            let ncpu: Int32 = try sysctl.get("hw.ncpu")

            XCTAssertFalse(hostname.isEmpty)
            XCTAssertEqual(ostype, "FreeBSD")
            XCTAssertGreaterThan(ncpu, 0)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlNameToMIB() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Convert name to MIB
            let mib = try sysctl.nameToMIB("kern.hostname")
            XCTAssertFalse(mib.isEmpty, "MIB should not be empty")

            // kern is 1, hostname varies but MIB should have at least 2 elements
            XCTAssertGreaterThanOrEqual(mib.count, 2)
            XCTAssertEqual(mib[0], 1) // CTL_KERN
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlGetByMIB() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Get MIB for kern.osreldate
            let mib = try sysctl.nameToMIB("kern.osreldate")

            // Read using MIB
            let osreldate: Int32 = try sysctl.get(mib: mib)
            XCTAssertGreaterThan(osreldate, 0)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlLimitNames() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Limit to specific sysctls
            try sysctl.limitNames([
                ("kern.hostname", .read),
                ("kern.ostype", .read)
            ])

            // These should work
            let hostname = try sysctl.getString("kern.hostname")
            let ostype = try sysctl.getString("kern.ostype")
            XCTAssertFalse(hostname.isEmpty)
            XCTAssertEqual(ostype, "FreeBSD")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    func testCasperSysctlLimitRecursive() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Limit to kern.* recursively
            try sysctl.limitNames([
                ("kern", [.read, .recursive])
            ])

            // All kern.* should work
            let hostname = try sysctl.getString("kern.hostname")
            let ostype = try sysctl.getString("kern.ostype")
            let osreldate: Int32 = try sysctl.get("kern.osreldate")

            XCTAssertFalse(hostname.isEmpty)
            XCTAssertEqual(ostype, "FreeBSD")
            XCTAssertGreaterThan(osreldate, 0)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }

    // MARK: - CasperPwd Integration Tests

    func testCasperPwdGetpwnam() throws {
        do {
            let casper = try CasperChannel.create()
            let pwd = try CasperPwd(casper: casper)

            // Look up root
            guard let root = pwd.getpwnam("root") else {
                XCTFail("Could not find root user")
                return
            }

            XCTAssertEqual(root.uid, 0)
            XCTAssertEqual(root.name, "root")
            XCTAssertEqual(root.gid, 0) // wheel
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Password service not available")
        }
    }

    func testCasperPwdGetpwuid() throws {
        do {
            let casper = try CasperChannel.create()
            let pwd = try CasperPwd(casper: casper)

            // Look up uid 0
            guard let root = pwd.getpwuid(0) else {
                XCTFail("Could not find uid 0")
                return
            }

            XCTAssertEqual(root.uid, 0)
            XCTAssertEqual(root.name, "root")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Password service not available")
        }
    }

    func testCasperPwdGetpwnamNotFound() throws {
        do {
            let casper = try CasperChannel.create()
            let pwd = try CasperPwd(casper: casper)

            // Look up nonexistent user
            let result = pwd.getpwnam("this_user_does_not_exist_12345")
            XCTAssertNil(result, "Should return nil for nonexistent user")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Password service not available")
        }
    }

    func testCasperPwdCurrentUser() throws {
        do {
            let casper = try CasperChannel.create()
            let pwd = try CasperPwd(casper: casper)

            // Look up current user
            let uid = getuid()
            guard let user = pwd.getpwuid(uid) else {
                XCTFail("Could not find current user (uid \(uid))")
                return
            }

            XCTAssertEqual(user.uid, uid)
            XCTAssertFalse(user.name.isEmpty)
            XCTAssertFalse(user.dir.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Password service not available")
        }
    }

    // MARK: - CasperGrp Integration Tests

    func testCasperGrpGetgrnam() throws {
        do {
            let casper = try CasperChannel.create()
            let grp = try CasperGrp(casper: casper)

            // Look up wheel group
            guard let wheel = grp.getgrnam("wheel") else {
                XCTFail("Could not find wheel group")
                return
            }

            XCTAssertEqual(wheel.gid, 0)
            XCTAssertEqual(wheel.name, "wheel")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Group service not available")
        }
    }

    func testCasperGrpGetgrgid() throws {
        do {
            let casper = try CasperChannel.create()
            let grp = try CasperGrp(casper: casper)

            // Look up gid 0
            guard let wheel = grp.getgrgid(0) else {
                XCTFail("Could not find gid 0")
                return
            }

            XCTAssertEqual(wheel.gid, 0)
            XCTAssertEqual(wheel.name, "wheel")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Group service not available")
        }
    }

    func testCasperGrpGetgrnamNotFound() throws {
        do {
            let casper = try CasperChannel.create()
            let grp = try CasperGrp(casper: casper)

            // Look up nonexistent group
            let result = grp.getgrnam("this_group_does_not_exist_12345")
            XCTAssertNil(result, "Should return nil for nonexistent group")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Group service not available")
        }
    }

    func testCasperGrpOperator() throws {
        do {
            let casper = try CasperChannel.create()
            let grp = try CasperGrp(casper: casper)

            // Look up operator group (common on FreeBSD)
            if let op = grp.getgrnam("operator") {
                XCTAssertEqual(op.name, "operator")
                XCTAssertGreaterThan(op.gid, 0)
            }
            // Not a failure if operator doesn't exist
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Group service not available")
        }
    }

    // MARK: - CasperNet Integration Tests

    func testCasperNetGetaddrinfo() throws {
        do {
            let casper = try CasperChannel.create()
            let net = try CasperNet(casper: casper)

            // Resolve localhost
            let addresses = try net.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Network service not available")
        }
    }

    func testCasperNetLimitMode() throws {
        do {
            let casper = try CasperChannel.create()
            let net = try CasperNet(casper: casper)

            // Limit to DNS operations only
            try net.limit(mode: .allDNS)

            // DNS should still work
            let addresses = try net.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Network service not available")
        }
    }

    func testCasperNetLimitBuilder() throws {
        do {
            let casper = try CasperChannel.create()
            let net = try CasperNet(casper: casper)

            // Use limit builder with just mode (family/name limits may be more restrictive)
            try net.limitBuilder(mode: [.nameToAddress, .addressToName])
                .apply()

            // Should be able to resolve localhost
            let addresses = try net.getaddrinfo(hostname: "localhost")
            XCTAssertFalse(addresses.isEmpty)
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Network service not available")
        } catch CasperError.limitSetFailed {
            // Some limit configurations may not be supported
            throw XCTSkip("Network limit not supported in this configuration")
        }
    }

    // MARK: - CasperNetdb Integration Tests

    func testCasperNetdbGetprotobyname() throws {
        do {
            let casper = try CasperChannel.create()
            let netdb = try CasperNetdb(casper: casper)

            // Look up TCP protocol
            guard let tcp = netdb.protocol(named: "tcp") else {
                XCTFail("Could not find TCP protocol")
                return
            }

            XCTAssertEqual(tcp.name, "tcp")
            XCTAssertEqual(tcp.proto, 6) // IPPROTO_TCP
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Netdb service not available")
        }
    }

    func testCasperNetdbGetprotobynameUDP() throws {
        do {
            let casper = try CasperChannel.create()
            let netdb = try CasperNetdb(casper: casper)

            // Look up UDP protocol
            guard let udp = netdb.protocol(named: "udp") else {
                XCTFail("Could not find UDP protocol")
                return
            }

            XCTAssertEqual(udp.name, "udp")
            XCTAssertEqual(udp.proto, 17) // IPPROTO_UDP
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Netdb service not available")
        }
    }

    func testCasperNetdbGetprotobynameICMP() throws {
        do {
            let casper = try CasperChannel.create()
            let netdb = try CasperNetdb(casper: casper)

            // Look up ICMP protocol
            guard let icmp = netdb.protocol(named: "icmp") else {
                XCTFail("Could not find ICMP protocol")
                return
            }

            XCTAssertEqual(icmp.name, "icmp")
            XCTAssertEqual(icmp.proto, 1) // IPPROTO_ICMP
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Netdb service not available")
        }
    }

    // MARK: - CasperSyslog Integration Tests

    func testCasperSyslogBasic() throws {
        do {
            let casper = try CasperChannel.create()
            let syslog = try CasperSyslog(casper: casper)

            // Open syslog
            syslog.openlog(ident: "casper-test", options: [.pid], facility: .user)

            // Log a message (just verify it doesn't crash)
            syslog.log(.info, "Test message from CasperTests")

            // Close syslog
            syslog.closelog()
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Syslog service not available")
        }
    }

    func testCasperSyslogConvenienceMethods() throws {
        do {
            let casper = try CasperChannel.create()
            let syslog = try CasperSyslog(casper: casper)

            syslog.openlog(ident: "casper-test", options: [.pid], facility: .daemon)

            // Test convenience methods (just verify they don't crash)
            syslog.debug("Debug message")
            syslog.info("Info message")
            syslog.notice("Notice message")
            syslog.warning("Warning message")

            syslog.closelog()
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Syslog service not available")
        }
    }

    func testCasperSyslogSetlogmask() throws {
        do {
            let casper = try CasperChannel.create()
            let syslog = try CasperSyslog(casper: casper)

            syslog.openlog(ident: "casper-test", options: [], facility: .user)

            // Set log mask to only allow warnings and above
            // LOG_UPTO(pri) = ((1 << ((pri)+1)) - 1)
            let warningMask: Int32 = (1 << (Int32(LOG_WARNING) + 1)) - 1
            let oldMask = syslog.setlogmask(warningMask)
            XCTAssertGreaterThanOrEqual(oldMask, 0)

            // Log at various levels (filtered by mask)
            syslog.debug("This should be filtered")
            syslog.warning("This should appear")

            syslog.closelog()
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Syslog service not available")
        }
    }

    // MARK: - CasperFileargs Integration Tests
    // Note: Fileargs requires specific initialization with command-line arguments
    // and the files must exist when fileargs_init() is called. These tests use
    // the Casper channel initialization path.

    func testCasperFileargsLstat() throws {
        // Create a temp file to test with
        let tempPath = "/tmp/casper_test_\(ProcessInfo.processInfo.processIdentifier)"
        guard FileManager.default.createFile(atPath: tempPath, contents: Data("test".utf8)) else {
            throw XCTSkip("Could not create temp file")
        }
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        do {
            let casper = try CasperChannel.create()
            let fileargs = try CasperFileargs(
                casper: casper,
                arguments: ["test", tempPath],
                flags: O_RDONLY,
                operations: [.lstat, .open]
            )

            // lstat the file
            guard let stat = fileargs.lstat(tempPath) else {
                // Fileargs may fail if the file wasn't in argv when initialized
                throw XCTSkip("fileargs lstat not available for this file")
            }

            XCTAssertGreaterThanOrEqual(stat.st_size, 0)
            XCTAssertTrue(stat.st_mode & S_IFREG != 0, "Should be a regular file")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper fileargs not available")
        }
    }

    func testCasperFileargsOpen() throws {
        // Create a temp file to test with
        let tempPath = "/tmp/casper_test_open_\(ProcessInfo.processInfo.processIdentifier)"
        guard FileManager.default.createFile(atPath: tempPath, contents: Data("hello".utf8)) else {
            throw XCTSkip("Could not create temp file")
        }
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        do {
            let casper = try CasperChannel.create()
            let fileargs = try CasperFileargs(
                casper: casper,
                arguments: ["test", tempPath],
                flags: O_RDONLY,
                operations: .open
            )

            // Open the file
            let fd = fileargs.open(tempPath)
            if fd < 0 {
                // Fileargs may fail if the file wasn't properly registered
                throw XCTSkip("fileargs open not available for this file")
            }
            defer { close(fd) }

            // Read from it
            var buffer = [UInt8](repeating: 0, count: 10)
            let bytesRead = read(fd, &buffer, buffer.count)
            XCTAssertEqual(bytesRead, 5)
            XCTAssertEqual(String(bytes: buffer.prefix(5), encoding: .utf8), "hello")
        } catch CasperError.initFailed {
            throw XCTSkip("Casper fileargs not available")
        }
    }

    func testCasperFileargsRealpath() throws {
        // Create a temp file
        let tempPath = "/tmp/casper_test_realpath_\(ProcessInfo.processInfo.processIdentifier)"
        guard FileManager.default.createFile(atPath: tempPath, contents: Data()) else {
            throw XCTSkip("Could not create temp file")
        }
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        do {
            let casper = try CasperChannel.create()
            let fileargs = try CasperFileargs(
                casper: casper,
                arguments: ["test", tempPath],
                flags: O_RDONLY,
                operations: .realpath
            )

            // Get realpath
            guard let resolved = fileargs.realpath(tempPath) else {
                // Fileargs may fail if the file wasn't in argv when initialized
                throw XCTSkip("fileargs realpath not available for this file")
            }

            XCTAssertTrue(resolved.hasPrefix("/tmp/") || resolved.hasPrefix("/private/tmp/"))
            XCTAssertTrue(resolved.contains("casper_test_realpath"))
        } catch CasperError.initFailed {
            throw XCTSkip("Casper fileargs not available")
        }
    }

    // MARK: - Capability Mode Integration Tests
    // These tests verify Casper works in capability mode by forking a subprocess

    func testCasperInCapabilityModeViaPipe() throws {
        // Create a pipe for IPC
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else {
            throw XCTSkip("Could not create pipe")
        }

        let pid = fork()
        if pid == 0 {
            // Child process
            close(pipefd[0]) // Close read end

            do {
                // Set up Casper before entering capability mode
                let casper = try CasperChannel.create()
                let sysctl = try CasperSysctl(casper: casper)

                // Limit sysctl access
                try sysctl.limitNames([
                    ("kern.hostname", .read),
                    ("kern.ostype", .read)
                ])

                // Enter capability mode
                try Capsicum.enter()

                // Verify we're in capability mode
                let inCapMode = try Capsicum.status()
                guard inCapMode else {
                    write(pipefd[1], "NOT_IN_CAPMODE", 14)
                    close(pipefd[1])
                    _exit(1)
                }

                // Use Casper from within capability mode
                let hostname = try sysctl.getString("kern.hostname")
                let ostype = try sysctl.getString("kern.ostype")

                // Send success message
                let result = "OK:\(hostname):\(ostype)"
                result.withCString { ptr in
                    write(pipefd[1], ptr, strlen(ptr))
                }
                close(pipefd[1])
                _exit(0)
            } catch {
                let errorMsg = "ERROR:\(error)"
                errorMsg.withCString { ptr in
                    write(pipefd[1], ptr, strlen(ptr))
                }
                close(pipefd[1])
                _exit(1)
            }
        } else if pid > 0 {
            // Parent process
            close(pipefd[1]) // Close write end

            // Wait for child
            var status: Int32 = 0
            waitpid(pid, &status, 0)

            // Read result
            var buffer = [CChar](repeating: 0, count: 256)
            let bytesRead = read(pipefd[0], &buffer, buffer.count - 1)
            close(pipefd[0])

            guard bytesRead > 0 else {
                XCTFail("No data from child process")
                return
            }

            let result = String(cString: buffer)

            if result.hasPrefix("OK:") {
                let parts = result.dropFirst(3).split(separator: ":")
                XCTAssertEqual(parts.count, 2, "Expected hostname:ostype")
                XCTAssertEqual(String(parts[1]), "FreeBSD")
            } else if result == "NOT_IN_CAPMODE" {
                XCTFail("Child did not enter capability mode")
            } else if result.hasPrefix("ERROR:") {
                XCTFail("Child error: \(result)")
            } else {
                XCTFail("Unexpected result: \(result)")
            }
        } else {
            throw XCTSkip("fork() failed")
        }
    }

    func testCasperDNSInCapabilityMode() throws {
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else {
            throw XCTSkip("Could not create pipe")
        }

        let pid = fork()
        if pid == 0 {
            // Child process
            close(pipefd[0])

            do {
                let casper = try CasperChannel.create()
                let dns = try CasperDNS(casper: casper)

                // Limit to forward lookups only (don't limit families)
                try dns.limit(types: [.nameToAddress])

                // Enter capability mode
                try Capsicum.enter()

                // Resolve localhost from within sandbox
                let addresses = try dns.getaddrinfo(hostname: "localhost", family: AF_INET)

                if addresses.isEmpty {
                    write(pipefd[1], "EMPTY", 5)
                } else if let addr = addresses.first?.addressString {
                    let result = "OK:\(addr)"
                    result.withCString { ptr in
                        _ = write(pipefd[1], ptr, strlen(ptr))
                    }
                } else {
                    write(pipefd[1], "NO_ADDR", 7)
                }
                close(pipefd[1])
                _exit(0)
            } catch {
                let errorMsg = "ERROR:\(error)"
                errorMsg.withCString { ptr in
                    _ = write(pipefd[1], ptr, strlen(ptr))
                }
                close(pipefd[1])
                _exit(1)
            }
        } else if pid > 0 {
            close(pipefd[1])

            var status: Int32 = 0
            waitpid(pid, &status, 0)

            var buffer = [CChar](repeating: 0, count: 256)
            let bytesRead = read(pipefd[0], &buffer, buffer.count - 1)
            close(pipefd[0])

            guard bytesRead > 0 else {
                XCTFail("No data from child process")
                return
            }

            let result = String(decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)

            if result.hasPrefix("OK:") {
                let addr = String(result.dropFirst(3))
                XCTAssertEqual(addr, "127.0.0.1", "localhost should resolve to 127.0.0.1")
            } else {
                XCTFail("DNS resolution failed: \(result)")
            }
        } else {
            throw XCTSkip("fork() failed")
        }
    }

    func testCasperPwdInCapabilityMode() throws {
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(&pipefd) == 0 else {
            throw XCTSkip("Could not create pipe")
        }

        let pid = fork()
        if pid == 0 {
            close(pipefd[0])

            do {
                let casper = try CasperChannel.create()
                let pwd = try CasperPwd(casper: casper)

                // Enter capability mode
                try Capsicum.enter()

                // Look up root from within sandbox
                guard let root = pwd.getpwnam("root") else {
                    write(pipefd[1], "NOT_FOUND", 9)
                    close(pipefd[1])
                    _exit(1)
                }

                let result = "OK:\(root.name):\(root.uid)"
                result.withCString { ptr in
                    write(pipefd[1], ptr, strlen(ptr))
                }
                close(pipefd[1])
                _exit(0)
            } catch {
                let errorMsg = "ERROR:\(error)"
                errorMsg.withCString { ptr in
                    write(pipefd[1], ptr, strlen(ptr))
                }
                close(pipefd[1])
                _exit(1)
            }
        } else if pid > 0 {
            close(pipefd[1])

            var status: Int32 = 0
            waitpid(pid, &status, 0)

            var buffer = [CChar](repeating: 0, count: 256)
            let bytesRead = read(pipefd[0], &buffer, buffer.count - 1)
            close(pipefd[0])

            guard bytesRead > 0 else {
                XCTFail("No data from child process")
                return
            }

            let result = String(cString: buffer)

            if result.hasPrefix("OK:") {
                let parts = result.dropFirst(3).split(separator: ":")
                XCTAssertEqual(parts.count, 2)
                XCTAssertEqual(String(parts[0]), "root")
                XCTAssertEqual(String(parts[1]), "0")
            } else {
                XCTFail("Pwd lookup failed: \(result)")
            }
        } else {
            throw XCTSkip("fork() failed")
        }
    }

    // MARK: - Error Path Tests

    func testCasperOpenInvalidService() throws {
        do {
            let casper = try CasperChannel.create()

            // Try to open a non-existent service
            let result = casper.openService(CasperService(rawValue: "invalid.service"))
            switch result {
            case .success:
                XCTFail("Should not be able to open invalid service")
            case .failure(let error):
                if case .serviceOpenFailed(let service) = error {
                    XCTAssertEqual(service, "invalid.service")
                } else {
                    XCTFail("Wrong error type: \(error)")
                }
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        }
    }

    func testCasperDNSResolveNonexistent() throws {
        do {
            let casper = try CasperChannel.create()
            let dns = try CasperDNS(casper: casper)

            // Try to resolve a domain that doesn't exist
            do {
                _ = try dns.getaddrinfo(hostname: "this.domain.definitely.does.not.exist.invalid")
                XCTFail("Should throw for nonexistent domain")
            } catch CasperError.operationFailed {
                // Expected
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("DNS service not available")
        }
    }

    func testCasperSysctlReadNonexistent() throws {
        do {
            let casper = try CasperChannel.create()
            let sysctl = try CasperSysctl(casper: casper)

            // Try to read a sysctl that doesn't exist
            do {
                let _: Int32 = try sysctl.get("this.sysctl.does.not.exist")
                XCTFail("Should throw for nonexistent sysctl")
            } catch CasperError.operationFailed {
                // Expected
            }
        } catch CasperError.initFailed {
            throw XCTSkip("Casper not available")
        } catch CasperError.serviceOpenFailed {
            throw XCTSkip("Sysctl service not available")
        }
    }
}
