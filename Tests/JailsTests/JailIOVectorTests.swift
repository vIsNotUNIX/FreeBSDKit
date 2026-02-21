import XCTest
@testable import Jails   // or FreeBSDKit / your module name
import Glibc

final class JailIOVectorTests: XCTestCase {

    func testStartsEmpty() {
        let iov = JailIOVector()
        XCTAssertEqual(iov.count, 0)
    }

    func testPairsAreAlwaysEven() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "test")
        XCTAssertEqual(iov.count % 2, 0)

        try iov.addInt32("jid", 42)
        XCTAssertEqual(iov.count % 2, 0)
    }

    func testAddCStringProducesTwoIOVecs() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "testjail")

        XCTAssertEqual(iov.count, 2)
    }

    func testCStringKeyAndValueAreCorrect() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "test")

        iov.withUnsafeMutableIOVecs { buf in
            let key = buf[0]
            let val = buf[1]

            XCTAssertEqual(
                String(cString: key.iov_base!.assumingMemoryBound(to: CChar.self)),
                "name"
            )
            XCTAssertEqual(
                String(cString: val.iov_base!.assumingMemoryBound(to: CChar.self)),
                "test"
            )
        }
    }

    func testCStringLengthsIncludeNullTerminator() throws {
        let iov = JailIOVector()
        try iov.addCString("abc", value: "xyz")

        iov.withUnsafeMutableIOVecs { buf in
            XCTAssertEqual(buf[0].iov_len, 4) // "abc\0"
            XCTAssertEqual(buf[1].iov_len, 4) // "xyz\0"
        }
    }

    func testAddInt32Layout() throws {
        let iov = JailIOVector()
        try iov.addInt32("jid", 123)

        iov.withUnsafeMutableIOVecs { buf in
            let value = buf[1]

            XCTAssertEqual(value.iov_len, MemoryLayout<Int32>.size)
            XCTAssertEqual(
                value.iov_base!.load(as: Int32.self),
                123
            )
        }
    }

    func testAddUInt32Layout() throws {
        let iov = JailIOVector()
        try iov.addUInt32("flags", 0xdeadbeef)

        iov.withUnsafeMutableIOVecs { buf in
            let value = buf[1]

            XCTAssertEqual(value.iov_len, MemoryLayout<UInt32>.size)
            XCTAssertEqual(
                value.iov_base!.load(as: UInt32.self),
                0xdeadbeef
            )
        }
    }

    func testAddInt64Layout() throws {
        let iov = JailIOVector()
        try iov.addInt64("hostid", 0x1122334455667788)

        iov.withUnsafeMutableIOVecs { buf in
            let value = buf[1]

            XCTAssertEqual(value.iov_len, MemoryLayout<Int64>.size)
            XCTAssertEqual(
                value.iov_base!.load(as: Int64.self),
                0x1122334455667788
            )
        }
    }

    func testBoolTrueEncodesAsOne() throws {
        let iov = JailIOVector()
        try iov.addBool("persist", true)

        iov.withUnsafeMutableIOVecs { buf in
            let value = buf[1]
            XCTAssertEqual(value.iov_len, MemoryLayout<Int32>.size)
            XCTAssertEqual(value.iov_base!.load(as: Int32.self), 1)
        }
    }

    func testBoolFalseEncodesAsZero() throws {
        let iov = JailIOVector()
        try iov.addBool("persist", false)

        iov.withUnsafeMutableIOVecs { buf in
            let value = buf[1]
            XCTAssertEqual(value.iov_base!.load(as: Int32.self), 0)
        }
    }

    func testKeyValueOrdering() throws {
        let iov = JailIOVector()
        try iov.addCString("name", value: "a")
        try iov.addInt32("jid", 1)

        iov.withUnsafeMutableIOVecs { buf in
            let key1 = String(cString: buf[0].iov_base!.assumingMemoryBound(to: CChar.self))
            let key2 = String(cString: buf[2].iov_base!.assumingMemoryBound(to: CChar.self))

            XCTAssertEqual(key1, "name")
            XCTAssertEqual(key2, "jid")
        }
    }

    func testWithUnsafeMutableIOVecsProvidesMutableAccess() throws {
        let iov = JailIOVector()
        try iov.addInt32("jid", 10)

        let rc: Int32 = iov.withUnsafeMutableIOVecs { buf in
            XCTAssertEqual(buf.count, 2)
            return 0
        }

        XCTAssertEqual(rc, 0)
    }
}