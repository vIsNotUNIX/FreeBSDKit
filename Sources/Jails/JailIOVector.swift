/// Safe builder for `jail_set` / `jail_get` iovecs.
///
/// All pointer unsafety is contained inside this type.
/// 
/// 
import CJails
import Glibc

public struct JailIOVector {

    public var iovecs: [iovec] = []
    fileprivate var backing: [Any] = []

    public init() {}

    /// Add a C-string parameter.
    public mutating func addCString(
        _ name: String,
        value: String
    ) {
        let key = strdup(name)
        let val = strdup(value)

        backing.append(key!)
        backing.append(val!)

        let keyVec = iovec(
            iov_base: UnsafeMutableRawPointer(key),
            iov_len: name.utf8.count + 1
        )

        let valueVec = iovec(
            iov_base: UnsafeMutableRawPointer(val),
            iov_len: value.utf8.count + 1
        )

        iovecs.append(keyVec)
        iovecs.append(valueVec)
    }
}

public extension JailIOVector {

    mutating func addInt32(_ name: String, _ value: Int32) {
        addRaw(name: name, value: value)
    }

    mutating func addUInt32(_ name: String, _ value: UInt32) {
        addRaw(name: name, value: value)
    }

    mutating func addInt64(_ name: String, _ value: Int64) {
        addRaw(name: name, value: value)
    }

    mutating func addBool(_ name: String, _ value: Bool) {
        let v: Int32 = value ? 1 : 0
        addRaw(name: name, value: v)
    }

    // MARK: - Internal raw helper (the only unsafe part)

    private mutating func addRaw<T>(
        name: String,
        value: T
    ) {
        precondition(MemoryLayout<T>.stride == MemoryLayout<T>.size,
                     "Type must be POD")

        let key = strdup(name)!
        let val = UnsafeMutablePointer<T>.allocate(capacity: 1)
        val.initialize(to: value)

        backing.append(key)
        backing.append(val)

        let keyVec = iovec(
            iov_base: UnsafeMutableRawPointer(key),
            iov_len: name.utf8.count + 1
        )

        let valueVec = iovec(
            iov_base: UnsafeMutableRawPointer(val),
            iov_len: MemoryLayout<T>.size
        )

        iovecs.append(keyVec)
        iovecs.append(valueVec)
    }
}