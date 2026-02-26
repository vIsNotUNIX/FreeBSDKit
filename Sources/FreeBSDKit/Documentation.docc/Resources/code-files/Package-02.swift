// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MyFreeBSDApp",
    dependencies: [
        .package(url: "https://github.com/koryheard/FreeBSDKit", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyFreeBSDApp",
            dependencies: [
                .product(name: "FreeBSDKit", package: "FreeBSDKit"),
                .product(name: "Capsicum", package: "FreeBSDKit"),
                .product(name: "Descriptors", package: "FreeBSDKit")
            ]
        )
    ]
)
