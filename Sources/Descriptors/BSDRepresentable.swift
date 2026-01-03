import Foundation

public protocol BSDRepresentable: ~Copyable {
    associatedtype RAWBSD
    consuming func take() -> RAWBSD
    @_spi(CapsicumInternal)
    func unsafeBorrow(_ block: (Int32) -> Void)
}