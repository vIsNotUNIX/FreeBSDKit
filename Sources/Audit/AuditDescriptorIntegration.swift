/*
 * Copyright (c) 2026 Kory Heard
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

import CAudit
import Descriptors
import Glibc

// MARK: - Descriptor Integration for Audit Pipe

extension Audit.Pipe {
    /// Creates an audit pipe from an existing file descriptor.
    ///
    /// This is useful when you have a FileCapability or other descriptor
    /// type that you want to use as an audit pipe.
    ///
    /// - Parameter descriptor: A file descriptor opened on /dev/auditpipe.
    /// - Returns: An audit pipe wrapper.
    /// - Note: The caller retains ownership of the descriptor.
    public static func from<D: Descriptor>(
        _ descriptor: borrowing D
    ) -> AuditPipeView where D: ~Copyable {
        descriptor.unsafe { fd in
            AuditPipeView(fd: fd)
        }
    }

    /// A non-owning view of an audit pipe descriptor.
    ///
    /// Unlike `Audit.Pipe`, this does not close the descriptor on deallocation.
    /// Use this when working with descriptors from the Capabilities module.
    public struct AuditPipeView {
        private let fd: Int32

        internal init(fd: Int32) {
            self.fd = fd
        }

        /// The file descriptor.
        public var fileDescriptor: Int32 { fd }

        // MARK: - Queue Management

        /// Gets the current queue length.
        public func getQueueLength() throws -> UInt32 {
            var qlen: UInt32 = 0
            if ioctl(fd, caudit_pipe_get_qlen_cmd(), &qlen) != 0 {
                throw Audit.Error(errno: errno)
            }
            return qlen
        }

        /// Gets the current queue limit.
        public func getQueueLimit() throws -> UInt32 {
            var qlimit: UInt32 = 0
            if ioctl(fd, caudit_pipe_get_qlimit_cmd(), &qlimit) != 0 {
                throw Audit.Error(errno: errno)
            }
            return qlimit
        }

        /// Sets the queue limit.
        public func setQueueLimit(_ limit: UInt32) throws {
            var qlimit = limit
            if ioctl(fd, caudit_pipe_set_qlimit_cmd(), &qlimit) != 0 {
                throw Audit.Error(errno: errno)
            }
        }

        // MARK: - Preselection

        /// Gets the preselection mask.
        public func getPreselectionMask() throws -> Audit.Mask {
            var mask = au_mask_t()
            if ioctl(fd, caudit_pipe_get_preselect_flags_cmd(), &mask) != 0 {
                throw Audit.Error(errno: errno)
            }
            return Audit.Mask(from: mask)
        }

        /// Sets the preselection mask.
        public func setPreselectionMask(_ mask: Audit.Mask) throws {
            var m = mask.toC()
            if ioctl(fd, caudit_pipe_set_preselect_flags_cmd(), &m) != 0 {
                throw Audit.Error(errno: errno)
            }
        }

        /// Flushes the queue.
        public func flush() throws {
            if ioctl(fd, caudit_pipe_flush_cmd()) != 0 {
                throw Audit.Error(errno: errno)
            }
        }

        // MARK: - Statistics

        /// Gets the drop count.
        public func getDropCount() throws -> UInt64 {
            var count: UInt64 = 0
            if ioctl(fd, caudit_pipe_get_drops_cmd(), &count) != 0 {
                throw Audit.Error(errno: errno)
            }
            return count
        }

        // MARK: - Reading

        /// Gets the maximum audit data size.
        public func getMaxAuditDataSize() throws -> UInt32 {
            var size: UInt32 = 0
            if ioctl(fd, caudit_pipe_get_maxauditdata_cmd(), &size) != 0 {
                throw Audit.Error(errno: errno)
            }
            return size
        }

        /// Reads a raw audit record.
        public func readRawRecord() throws -> [UInt8]? {
            let maxSize = try getMaxAuditDataSize()
            var buffer = [UInt8](repeating: 0, count: Int(maxSize))

            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead < 0 {
                throw Audit.Error(errno: errno)
            }
            if bytesRead == 0 {
                return nil
            }

            return Array(buffer.prefix(bytesRead))
        }
    }
}

// MARK: - Process Descriptor Integration

extension Audit {
    /// Gets the audit information for a process identified by a descriptor.
    ///
    /// - Parameter descriptor: A process descriptor.
    /// - Returns: The process's audit information.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges.
    public static func getAuditInfo<D: ProcessDescriptor>(
        for descriptor: borrowing D
    ) throws -> AuditInfo where D: ~Copyable {
        let pid = try descriptor.pid()

        // Use auditon with A_GETPINFO
        var pinfo = auditpinfo_t()
        pinfo.ap_pid = pid

        if caudit_auditon(A_GETPINFO, &pinfo, Int32(MemoryLayout<auditpinfo_t>.size)) != 0 {
            throw Error(errno: Glibc.errno)
        }

        return AuditInfo(
            auditID: pinfo.ap_auid,
            mask: Mask(from: pinfo.ap_mask),
            terminalID: TerminalID(from: pinfo.ap_termid),
            sessionID: pinfo.ap_asid
        )
    }

    /// Sets the audit mask for a process identified by a descriptor.
    ///
    /// - Parameters:
    ///   - mask: The new audit mask.
    ///   - descriptor: A process descriptor.
    /// - Throws: `Audit.Error` if the operation fails.
    /// - Note: Requires appropriate privileges.
    public static func setAuditMask<D: ProcessDescriptor>(
        _ mask: Mask,
        for descriptor: borrowing D
    ) throws where D: ~Copyable {
        let pid = try descriptor.pid()

        var pinfo = auditpinfo_t()
        pinfo.ap_pid = pid
        pinfo.ap_mask = mask.toC()

        if caudit_auditon(A_SETPMASK, &pinfo, Int32(MemoryLayout<auditpinfo_t>.size)) != 0 {
            throw Error(errno: Glibc.errno)
        }
    }
}
