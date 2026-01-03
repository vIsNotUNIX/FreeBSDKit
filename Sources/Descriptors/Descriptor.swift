import Foundation

public protocol Descriptor: BSDRepresentable, Sendable, ~Copyable
where RAWBSD == Int32 {
    init(_ value: RAWBSD)
    consuming func close()
}