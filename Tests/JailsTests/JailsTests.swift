/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
@testable import Jails

final class JailsTests: XCTestCase {

    // MARK: - JailConfiguration Tests

    func testJailConfigurationBasic() {
        let config = JailConfiguration(name: "testjail", path: "/jail/test")
        XCTAssertEqual(config.name, "testjail")
        XCTAssertEqual(config.path, "/jail/test")
        XCTAssertNil(config.hostname)
        XCTAssertFalse(config.persist)
        XCTAssertFalse(config.vnet)
    }

    func testJailConfigurationHostname() {
        var config = JailConfiguration(name: "web", path: "/jail/web")
        config.hostname = "web.local"
        config.domainname = "example.com"
        XCTAssertEqual(config.hostname, "web.local")
        XCTAssertEqual(config.domainname, "example.com")
    }

    func testJailConfigurationPersistence() {
        var config = JailConfiguration(name: "persist", path: "/jail/persist")
        config.persist = true
        config.childrenMax = 10
        XCTAssertTrue(config.persist)
        XCTAssertEqual(config.childrenMax, 10)
    }

    func testJailConfigurationNetwork() {
        var config = JailConfiguration(name: "net", path: "/jail/net")
        config.ip4Addresses = ["192.168.1.100", "192.168.1.101"]
        config.ip6Addresses = ["::1"]
        XCTAssertEqual(config.ip4Addresses.count, 2)
        XCTAssertEqual(config.ip6Addresses.count, 1)
    }

    func testJailConfigurationVnet() {
        var config = JailConfiguration(name: "vnet", path: "/jail/vnet")
        config.vnet = true
        XCTAssertTrue(config.vnet)
    }

    func testJailConfigurationPersistentFactory() {
        let config = JailConfiguration.persistent(name: "test", path: "/jail/test")
        XCTAssertTrue(config.persist)
    }

    func testJailConfigurationVnetFactory() {
        let config = JailConfiguration.vnet(name: "test", path: "/jail/test")
        XCTAssertTrue(config.vnet)
    }

    func testJailConfigurationLinuxFactory() {
        let config = JailConfiguration.linux(
            name: "linux",
            path: "/jail/linux",
            osname: "Linux",
            osrelease: "5.15.0"
        )
        XCTAssertEqual(config.linuxOsname, "Linux")
        XCTAssertEqual(config.linuxOsrelease, "5.15.0")
    }

    // MARK: - JailPermissions Tests

    func testJailPermissionsDefault() {
        let perms = JailPermissions()
        XCTAssertFalse(perms.allowRawSockets)
        XCTAssertFalse(perms.allowChflags)
        XCTAssertFalse(perms.allowSysvipc)
        XCTAssertTrue(perms.allowSuser) // Default is true
        XCTAssertTrue(perms.mountPermissions.isEmpty)
    }

    func testJailPermissionsSetters() {
        var perms = JailPermissions()
        perms.allowRawSockets = true
        perms.allowChflags = true
        perms.allowSetHostname = true
        XCTAssertTrue(perms.allowRawSockets)
        XCTAssertTrue(perms.allowChflags)
        XCTAssertTrue(perms.allowSetHostname)
    }

    func testJailPermissionsMount() {
        var perms = JailPermissions()
        perms.allowMount(.devfs)
        perms.allowMount(.tmpfs)
        perms.allowMount(.procfs)
        XCTAssertTrue(perms.mountPermissions.contains(.devfs))
        XCTAssertTrue(perms.mountPermissions.contains(.tmpfs))
        XCTAssertTrue(perms.mountPermissions.contains(.procfs))
        XCTAssertFalse(perms.mountPermissions.contains(.zfs))

        perms.disallowMount(.tmpfs)
        XCTAssertFalse(perms.mountPermissions.contains(.tmpfs))
    }

    func testJailPermissionsDevelopment() {
        let perms = JailPermissions.development
        XCTAssertTrue(perms.allowSetHostname)
        XCTAssertTrue(perms.allowRawSockets)
        XCTAssertTrue(perms.allowSysvipc)
        XCTAssertTrue(perms.mountPermissions.contains(.devfs))
    }

    func testJailPermissionsWebServer() {
        let perms = JailPermissions.webServer
        XCTAssertTrue(perms.allowReservedPorts)
        XCTAssertTrue(perms.mountPermissions.contains(.devfs))
    }

    func testJailPermissionsRestrictive() {
        let perms = JailPermissions.restrictive
        XCTAssertFalse(perms.allowSuser)
    }

    func testJailPermissionsArrayLiteral() {
        let perms: JailPermissions = [.rawSockets, .sysvipc, .mount(.devfs)]
        XCTAssertTrue(perms.allowRawSockets)
        XCTAssertTrue(perms.allowSysvipc)
        XCTAssertTrue(perms.mountPermissions.contains(.devfs))
    }

    // MARK: - JailInfo Tests

    func testJailInfoDescription() {
        let info = JailInfo(jid: 5, name: "test", path: "/jail/test", hostname: "test.local")
        XCTAssertEqual(info.description, "Jail(5: test at /jail/test)")
    }

    func testJailInfoEquatable() {
        let info1 = JailInfo(jid: 5, name: "test", path: "/jail/test", hostname: "test.local")
        let info2 = JailInfo(jid: 5, name: "test", path: "/jail/test", hostname: "test.local")
        let info3 = JailInfo(jid: 6, name: "test", path: "/jail/test", hostname: "test.local")
        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }

    // MARK: - JailHandle Tests

    func testJailHandleDescription() {
        let handle = JailHandle(jid: 5, name: "test", owning: true)
        XCTAssertEqual(handle.description, "JailHandle(5: test, isOwning: true)")

        let handleNoName = JailHandle(jid: 5, name: nil, owning: false)
        XCTAssertEqual(handleNoName.description, "JailHandle(5, isOwning: false)")
    }

    // MARK: - JailSetFlags Tests

    func testJailSetFlags() {
        var flags: JailSetFlags = [.create, .getDesc]
        XCTAssertTrue(flags.contains(.create))
        XCTAssertTrue(flags.contains(.getDesc))
        XCTAssertFalse(flags.contains(.attach))

        flags.insert(.ownDesc)
        XCTAssertTrue(flags.contains(.ownDesc))
    }

    // MARK: - JailGetFlags Tests

    func testJailGetFlags() {
        var flags: JailGetFlags = [.getDesc]
        XCTAssertTrue(flags.contains(.getDesc))
        XCTAssertFalse(flags.contains(.dying))

        flags.insert(.dying)
        XCTAssertTrue(flags.contains(.dying))
    }

    // MARK: - Jail Static Tests

    func testIsJailedOutsideJail() {
        // When running tests outside a jail, this should be false
        // Inside a jail, it would be true
        let jid = Jail.currentJid()
        // JID 0 means not in a jail
        if jid == 0 {
            XCTAssertFalse(Jail.isJailed)
        } else {
            XCTAssertTrue(Jail.isJailed)
        }
    }

    func testJailListEmpty() {
        // This test just verifies the list function works
        // It may return an empty list or existing jails
        do {
            let jails = try Jail.list()
            // Should be an array (possibly empty)
            _ = jails.count
        } catch {
            // Permission error is expected if not root
            // Just make sure we don't crash
        }
    }

    func testJailFindNonexistent() {
        do {
            let info = try Jail.find(name: "nonexistent_jail_12345")
            XCTAssertNil(info)
        } catch {
            // ENOENT would be converted to nil, other errors may throw
            // Just verify we don't crash
        }
    }

    // MARK: - JailIOVector Tests

    func testJailIOVectorString() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "test")
        XCTAssertEqual(iov.count, 2) // key + value
    }

    func testJailIOVectorInt32() throws {
        let iov = JailIOVector()
        try iov.addInt32("jid", 5)
        XCTAssertEqual(iov.count, 2)
    }

    func testJailIOVectorBool() throws {
        let iov = JailIOVector()
        try iov.addBool("persist", true)
        XCTAssertEqual(iov.count, 2)
    }

    func testJailIOVectorMultiple() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "test")
        try iov.addCString("path", value: "/jail/test")
        try iov.addBool("persist", true)
        XCTAssertEqual(iov.count, 6) // 3 pairs
    }
}
