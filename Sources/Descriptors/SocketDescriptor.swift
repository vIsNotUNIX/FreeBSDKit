/*
 * Copyright (c) 2026 Kory Heard
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import Glibc
import Foundation
import FreeBSDKit


public protocol SocketDescriptor: StreamDescriptor, ~Copyable {
    static func socket(domain: Int32, type: Int32, proto: Int32) throws -> Self
    func bind(address: UnsafePointer<sockaddr>, addrlen: socklen_t) throws
    func listen(backlog: Int32) throws
    func accept() throws -> Self
    func connect(address: UnsafePointer<sockaddr>, addrlen: socklen_t) throws
    func shutdown(how: Int32) throws
    // TODO: Convert to `OpaqueDescriptor`
    func sendDescriptors<D: StreamDescriptor>(_ descriptors: [D], payload: Data) throws
    // TODO Return struct with enumerated values.
    func recvDescriptors(maxDescriptors: Int, bufferSize: Int) throws -> (Data, [Int32])
}

// MARK: - Default implementations

public extension SocketDescriptor where Self: ~Copyable {

    func listen(backlog: Int32 = 128) throws {
        try self.unsafe { fd in
            guard Glibc.listen(fd, backlog) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }
     // TODO: OptionSet the how
    func shutdown(how: Int32) throws {
        try self.unsafe { fd in
            guard Glibc.shutdown(fd, how) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }
    // TODO: OptionSet this
    static func socket(domain: Int32, type: Int32, proto: Int32) throws -> Self {
        let rawFD = Glibc.socket(domain, type, proto)
        guard rawFD >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        return Self(rawFD)
    }

    func bind(address: UnsafePointer<sockaddr>, addrlen: socklen_t) throws {
        try self.unsafe { fd in
            guard Glibc.bind(fd, address, addrlen) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }

    func accept() throws -> Self {
        return try self.unsafe { fd in
            let newFD = Glibc.accept(fd, nil, nil)
            guard newFD >= 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
            return Self(newFD)
        }
    }

    func connect(address: UnsafePointer<sockaddr>, addrlen: socklen_t) throws {
        try self.unsafe { fd in
            guard Glibc.connect(fd, address, addrlen) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno)!)
            }
        }
    }
}
// TODO: Wrap these in C methods.
// MARK: - CMSG Helpers (Swift replacements for macros)

@inline(__always)
private func _CMSG_ALIGN(_ len: Int) -> Int {
    let align = MemoryLayout<cmsghdr>.alignment
    return (len + align - 1) & ~(align - 1)
}

@inline(__always)
private func CMSG_LEN(_ dataLen: Int) -> Int {
    _CMSG_ALIGN(MemoryLayout<cmsghdr>.size) + dataLen
}

@inline(__always)
private func CMSG_SPACE(_ dataLen: Int) -> Int {
    _CMSG_ALIGN(MemoryLayout<cmsghdr>.size) + _CMSG_ALIGN(dataLen)
}

@inline(__always)
private func CMSG_FIRSTHDR(_ msg: UnsafePointer<msghdr>) -> UnsafeMutablePointer<cmsghdr>? {
    guard msg.pointee.msg_controllen >= MemoryLayout<cmsghdr>.size else { return nil }
    return msg.pointee.msg_control?.assumingMemoryBound(to: cmsghdr.self)
}

@inline(__always)
private func CMSG_NXTHDR(
    _ msg: UnsafePointer<msghdr>,
    _ cmsg: UnsafePointer<cmsghdr>
) -> UnsafeMutablePointer<cmsghdr>? {
    let next = UnsafeRawPointer(cmsg)
        .advanced(by: _CMSG_ALIGN(Int(cmsg.pointee.cmsg_len)))

    let base = msg.pointee.msg_control!
    let end  = base.advanced(by: Int(msg.pointee.msg_controllen))

    guard next + MemoryLayout<cmsghdr>.size <= end else { return nil }
    return UnsafeMutablePointer(mutating: next.assumingMemoryBound(to: cmsghdr.self))
}

@inline(__always)
private func CMSG_DATA(_ cmsg: UnsafePointer<cmsghdr>) -> UnsafeMutableRawPointer {
    UnsafeMutableRawPointer(mutating: UnsafeRawPointer(cmsg))
        .advanced(by: _CMSG_ALIGN(MemoryLayout<cmsghdr>.size))
}

// TODO: Convert to `OpaqueDescriptor`
// Should take in opaque descriptors
public extension SocketDescriptor where Self: ~Copyable {

    func sendDescriptors<D: StreamDescriptor>(
        _ descriptors: [D],
        payload: Data
    ) throws {
        precondition(!payload.isEmpty)

        try self.unsafe { sockFD in
            var rawFDs: [Int32] = []
            rawFDs.reserveCapacity(descriptors.count)

            for d in descriptors {
                d.unsafe { rawFDs.append($0) }
            }

            let controlLen = CMSG_SPACE(rawFDs.count * MemoryLayout<Int32>.size)
            var control = [UInt8](repeating: 0, count: controlLen)

            try payload.withUnsafeBytes { payloadPtr in
                var iov = iovec(
                    iov_base: UnsafeMutableRawPointer(mutating: payloadPtr.baseAddress),
                    iov_len: payloadPtr.count
                )

                try control.withUnsafeMutableBytes { ctrlPtr in
                    try withUnsafeMutablePointer(to: &iov) { iovPtr in
                        var msg = msghdr(
                            msg_name: nil,
                            msg_namelen: 0,
                            msg_iov: iovPtr,
                            msg_iovlen: 1,
                            msg_control: ctrlPtr.baseAddress,
                            msg_controllen: socklen_t(ctrlPtr.count),
                            msg_flags: 0
                        )

                        guard let cmsg = CMSG_FIRSTHDR(&msg) else {
                            throw POSIXError(.EINVAL)
                        }

                        cmsg.pointee.cmsg_level = SOL_SOCKET
                        cmsg.pointee.cmsg_type  = SCM_RIGHTS
                        cmsg.pointee.cmsg_len   =
                            socklen_t(CMSG_LEN(rawFDs.count * MemoryLayout<Int32>.size))

                        let dataPtr = CMSG_DATA(cmsg).assumingMemoryBound(to: Int32.self)
                        for (i, fd) in rawFDs.enumerated() {
                            dataPtr[i] = fd
                        }

                        let ret = Glibc.sendmsg(sockFD, &msg, 0)
                        guard ret >= 0 else {
                            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
                        }
                    }
                }
            }
        }
    }

        
        func recvDescriptors(
        maxDescriptors: Int = 8,
        bufferSize: Int = 1
    ) throws -> (Data, [Int32]) {

        try self.unsafe { sockFD in
            var buffer  = [UInt8](repeating: 0, count: bufferSize)
            var control = [UInt8](
                repeating: 0,
                count: CMSG_SPACE(maxDescriptors * MemoryLayout<Int32>.size)
            )

            return try buffer.withUnsafeMutableBytes { bufPtr in
                try control.withUnsafeMutableBytes { ctrlPtr in

                    var iov = iovec(
                        iov_base: bufPtr.baseAddress,
                        iov_len: bufPtr.count
                    )

                    return try withUnsafeMutablePointer(to: &iov) { iovPtr in
                        var msg = msghdr(
                            msg_name: nil,
                            msg_namelen: 0,
                            msg_iov: iovPtr,
                            msg_iovlen: 1,
                            msg_control: ctrlPtr.baseAddress,
                            msg_controllen: socklen_t(ctrlPtr.count),
                            msg_flags: 0
                        )

                        let bytesRead = Glibc.recvmsg(sockFD, &msg, 0)
                        guard bytesRead >= 0 else {
                            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
                        }

                        if (msg.msg_flags & MSG_CTRUNC) != 0 {
                            throw POSIXError(.EMSGSIZE)
                        }

                        var receivedFDs: [Int32] = []

                        var cmsg = CMSG_FIRSTHDR(&msg)
                        while let hdr = cmsg {
                            if hdr.pointee.cmsg_level == SOL_SOCKET &&
                            hdr.pointee.cmsg_type  == SCM_RIGHTS {

                                let dataLen =
                                    Int(hdr.pointee.cmsg_len) - CMSG_LEN(0)

                                let count = dataLen / MemoryLayout<Int32>.size
                                let dataPtr =
                                    CMSG_DATA(hdr).assumingMemoryBound(to: Int32.self)

                                for i in 0..<count {
                                    receivedFDs.append(dataPtr[i])
                                }
                            }
                            cmsg = CMSG_NXTHDR(&msg, hdr)
                        }

                        // IMPORTANT: build Data from bufPtr, not `buffer`
                        let data = Data(
                            bytes: bufPtr.baseAddress!,
                            count: bytesRead
                        )

                        return (data, receivedFDs)
                    }
                }
            }
        }
    }


}
