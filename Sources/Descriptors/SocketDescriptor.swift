/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import Glibc
import Foundation
import FreeBSDKit

/// Socket descriptor protocol providing network communication capabilities
public protocol SocketDescriptor: StreamDescriptor, ~Copyable {
    static func socket(domain: SocketDomain, type: SocketType, protocol: SocketProtocol) throws -> Self
    func bind(address: SocketAddress) throws
    func listen(backlog: Int32) throws
    func accept() throws -> Self
    func connect(address: SocketAddress) throws
    func shutdown(how: SocketShutdown) throws
    func sendDescriptors(_ descriptors: [OpaqueDescriptorRef], payload: Data) throws
    func recvDescriptors(maxDescriptors: Int, bufferSize: Int) throws -> (Data, [OpaqueDescriptorRef])
}

// MARK: - Default implementations

public extension SocketDescriptor where Self: ~Copyable {

    func listen(backlog: Int32 = 128) throws {
        try self.unsafe { fd in
            guard Glibc.listen(fd, backlog) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    func shutdown(how: SocketShutdown) throws {
        try self.unsafe { fd in
            guard Glibc.shutdown(fd, how.rawValue) == 0 else {
                try BSDError.throwErrno(errno)
            }
        }
    }

    static func socket(domain: SocketDomain, type: SocketType, protocol: SocketProtocol) throws -> Self {
        let rawFD = Glibc.socket(domain.rawValue, type.rawValue, `protocol`.rawValue)
        guard rawFD >= 0 else {
            try BSDError.throwErrno(errno)
        }
        return Self(rawFD)
    }

    func bind(address: SocketAddress) throws {
        try self.unsafe { fd in
            try address.withSockAddr { addr, len in
                guard Glibc.bind(fd, addr, len) == 0 else {
                    try BSDError.throwErrno(errno)
                }
            }
        }
    }

    func accept() throws -> Self {
        return try self.unsafe { fd in
            let newFD = Glibc.accept(fd, nil, nil)
            guard newFD >= 0 else {
                try BSDError.throwErrno(errno)
            }
            return Self(newFD)
        }
    }

    func connect(address: SocketAddress) throws {
        try self.unsafe { fd in
            try address.withSockAddr { addr, len in
                guard Glibc.connect(fd, addr, len) == 0 else {
                    try BSDError.throwErrno(errno)
                }
            }
        }
    }
}

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

public extension SocketDescriptor where Self: ~Copyable {

    func sendDescriptors(
        _ descriptors: [OpaqueDescriptorRef],
        payload: Data
    ) throws {
        precondition(!payload.isEmpty)

        try self.unsafe { sockFD in
            var rawFDs: [RawDesc] = []
            rawFDs.reserveCapacity(descriptors.count)

            for d in descriptors {
                if let rawFD = d.toBSDValue() {
                    rawFDs.append(rawFD)
                }
            }

            let controlLen = CMSG_SPACE(rawFDs.count * MemoryLayout<RawDesc>.size)
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
                            socklen_t(CMSG_LEN(rawFDs.count * MemoryLayout<RawDesc>.size))

                        let dataPtr = CMSG_DATA(cmsg).assumingMemoryBound(to: RawDesc.self)
                        for (i, fd) in rawFDs.enumerated() {
                            dataPtr[i] = fd
                        }

                        let ret = Glibc.sendmsg(sockFD, &msg, 0)
                        guard ret >= 0 else {
                            try BSDError.throwErrno(errno)
                        }
                    }
                }
            }
        }
    }

        
    func recvDescriptors(
        maxDescriptors: Int = 8,
        bufferSize: Int = 1
    ) throws -> (Data, [OpaqueDescriptorRef]) {

        try self.unsafe { sockFD in
            var buffer  = [UInt8](repeating: 0, count: bufferSize)
            var control = [UInt8](
                repeating: 0,
                count: CMSG_SPACE(maxDescriptors * MemoryLayout<RawDesc>.size)
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
                            try BSDError.throwErrno(errno)
                        }

                        if (msg.msg_flags & MSG_CTRUNC) != 0 {
                            throw POSIXError(.EMSGSIZE)
                        }

                        var receivedFDs: [OpaqueDescriptorRef] = []

                        var cmsg = CMSG_FIRSTHDR(&msg)
                        while let hdr = cmsg {
                            if hdr.pointee.cmsg_level == SOL_SOCKET &&
                            hdr.pointee.cmsg_type  == SCM_RIGHTS {

                                let dataLen =
                                    Int(hdr.pointee.cmsg_len) - CMSG_LEN(0)

                                let count = dataLen / MemoryLayout<RawDesc>.size
                                let dataPtr =
                                    CMSG_DATA(hdr).assumingMemoryBound(to: Int32.self)

                                for i in 0..<count {
                                    receivedFDs.append(OpaqueDescriptorRef(dataPtr[i]))
                                }
                            }
                            cmsg = CMSG_NXTHDR(&msg, hdr)
                        }

                        // IMPORTANT: build Data from bufPtr, not `buffer`
                        let data = Data(
                            bytes: bufPtr.baseAddress!,
                            count: bytesRead
                        )

                        #if os(FreeBSD)
                            print("Running on FreeBSD")
                        #endif

                        return (data, receivedFDs)
                    }
                }
            }
        }
    }
}

public extension SocketDescriptor {
    static func socketPair(
        domain: SocketDomain,
        type: SocketType,
        protocol: SocketProtocol = .default
    ) throws -> (Self, Self) {
        var fds = [Int32](repeating: -1, count: 2)
        guard Glibc.socketpair(domain.rawValue, type.rawValue, `protocol`.rawValue, &fds) == 0 else {
            try BSDError.throwErrno(errno)
        }
        return (Self(fds[0]), Self(fds[1]))
    }
}