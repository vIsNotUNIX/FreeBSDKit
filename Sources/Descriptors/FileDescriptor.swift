import Glibc
import Foundation

struct FileDescriptor: Capability, Descriptor, ~Copyable {
    private var fd: Int32

    init(_ value: Int32) {
        self.fd = value
    }

    deinit {
        if fd >= 0 {
            Glibc.close(fd)
        }
    }

    consuming func close() {
        if fd >= 0 {
            Glibc.close(fd)
            fd = -1
        }
    }

    consuming func take() -> Int32 {
        let rawDescriptor = fd
        fd = -1
        return rawDescriptor
    }

    func unsafeBorrow(_ block: (Int32) -> Void) {
        block(fd)
    }

    // MARK: File specific operations
}