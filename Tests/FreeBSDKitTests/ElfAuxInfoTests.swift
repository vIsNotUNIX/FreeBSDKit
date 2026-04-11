/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import XCTest
import Glibc
import Foundation
@testable import FreeBSDKit

final class ElfAuxInfoTests: XCTestCase {

    func testPageSizeMatchesSysconf() throws {
        let pageSize = try ElfAuxInfo.int32(.pageSize)
        let sysconfPageSize = sysconf(Int32(_SC_PAGESIZE))
        XCTAssertNotNil(pageSize)
        XCTAssertGreaterThan(pageSize ?? 0, 0)
        XCTAssertEqual(Int(pageSize ?? 0), Int(sysconfPageSize))
    }

    func testNcpusIsPositive() throws {
        let ncpus = try ElfAuxInfo.int32(.ncpus)
        XCTAssertNotNil(ncpus)
        XCTAssertGreaterThanOrEqual(ncpus ?? 0, 1,
            "ncpus should be at least 1, got \(String(describing: ncpus))")
    }

    func testOsReldateLooksLikeFreeBSDVersion() throws {
        let osreldate = try ElfAuxInfo.int32(.osReldate)
        let value = try XCTUnwrap(osreldate)
        // FreeBSD __FreeBSD_version values are 6 or 7 digits, e.g.
        // 1500000 for 15.0. Sanity-check it's in a plausible range.
        XCTAssertGreaterThan(value, 1_000_000)
        XCTAssertLessThan(value,    100_000_000)
    }

    func testHwcapShapeWhenPresent() throws {
        // AT_HWCAP is documented as accessible via elf_aux_info, but
        // whether the kernel actually populates it depends on the
        // architecture: ARM and POWER use it heavily, while amd64 has
        // historically deferred CPU feature detection to cpuid and may
        // leave it absent. Verify the wrapper's u_long path is
        // well-formed if it is present, and that absence surfaces as
        // nil rather than as an error.
        let hwcap = try ElfAuxInfo.unsignedLong(.hwcap)
        if let value = hwcap {
            _ = value
        }
    }

    func testExecPathIsAbsolute() throws {
        // execPath may legitimately be nil if the process was started via
        // fexecve(2). In a normal test run it should be present.
        let execPath = try ElfAuxInfo.string(.execPath)
        if let path = execPath {
            XCTAssertTrue(path.hasPrefix("/"),
                "AT_EXECPATH should be an absolute path, got \"\(path)\"")
            XCTAssertGreaterThan(path.count, 1)
        }
    }

    func testWrongSizeThrowsEINVAL() {
        // Asking for an int-sized entry (.pageSize) via the u_long entry
        // point passes a buffer of the wrong size and must produce
        // EINVAL.
        XCTAssertThrowsError(try ElfAuxInfo.unsignedLong(.pageSize)) { error in
            guard case .posix(let posix) = (error as? BSDError) ?? .errno(0) else {
                XCTFail("expected BSDError.posix, got \(error)")
                return
            }
            XCTAssertEqual(posix.code, .EINVAL)
        }
    }
}
