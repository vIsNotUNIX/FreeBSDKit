// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MyFreeBSDApp",
    dependencies: [
        .package(url: "https://github.com/koryheard/FreeBSDKit", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyFreeBSDApp"
        )
    ]
)
