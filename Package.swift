// swift-tools-version: 5.10
// The FreeBSD ports tree still uses 5.10. You can build with 6.2

import PackageDescription

let package = Package(
    name: "FreeBSDKit",
    products: [
        .library(
            name: "FreeBSDKit",
            targets: ["FreeBSDKit"]
        ),
        .library(
            name: "Capsicum",
            targets: ["Capsicum"]
        ),
        .library(
            name: "Capabilites",
            targets: ["Capsicum"]
        ),
        .library(
            name: "Descriptors",
            targets: ["Descriptors"]
        ),
        .library(
            name: "SignalDispatchers",
            targets: ["SignalDispatchers"]
        ),
        .library(
            name: "FPC",
            targets: ["FPC"]
        ),
        .library(
            name: "MacLabel",
            targets: ["MacLabel"]
        ),
        .library(
            name: "CMacLabelParser",
            targets: ["CMacLabelParser"]
        ),
        .library(
            name: "Casper",
            targets: ["Casper"]
        ),
        .executable(
            name: "testtool",
            targets: ["TestTool"]
        ),
        .executable(
            name: "maclabel",
            targets: ["maclabel"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "FreeBSDKit",
            dependencies: ["CExtendedAttributes"]
        ),
        .target(
            name: "CCapsicum",
            path: "Sources/CCapsicum"
        ),
        .target(
            name: "CExtendedError",
            path: "Sources/CExtendedError"
        ),
        .target(
            name: "CExtendedAttributes",
            path: "Sources/CExtendedAttributes"
        ),
        .target(
            name: "Capsicum",
            dependencies: ["CCapsicum", "FreeBSDKit"]
        ),
        .target(
            name: "CProcessDescriptor",
            path: "Sources/CProcessDescriptor"
        ),
        .target(
            name: "CJails",
            path: "Sources/CJails"
        ),
        .target(
            name: "Jails",
            dependencies: ["CJails", "FreeBSDKit"],
            path: "Sources/Jails"

        ),
        .target(
            name: "CEventDescriptor",
            path: "Sources/CEventDescriptor"
        ),
        .target(
            name: "CINotify",
            path: "Sources/CINotify"
        ),
        .target(
            name: "CSignal",
            path: "Sources/CSignal"
        ),
        .target(
            name: "CDeviceIoctl",
            path: "Sources/CDeviceIoctl"
        ),
        .target(
            name: "CCasper",
            path: "Sources/CCasper",
            linkerSettings: [
                .linkedLibrary("casper"),
                .linkedLibrary("cap_dns"),
                .linkedLibrary("cap_sysctl"),
                .linkedLibrary("cap_pwd"),
                .linkedLibrary("cap_grp"),
                .linkedLibrary("cap_syslog"),
                .linkedLibrary("cap_fileargs"),
                .linkedLibrary("cap_net"),
                .linkedLibrary("cap_netdb")
            ]
        ),
        .target(
            name: "Casper",
            dependencies: ["CCasper", "FreeBSDKit"]
        ),
        .target(
            name: "Descriptors",
            dependencies: [
                "Capsicum", "CProcessDescriptor",
                "CEventDescriptor", "CJails", "Jails",
                "CINotify", "CDeviceIoctl"
            ]
        ),
        .target(
            name: "Capabilities",
            dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        ),
        .target(
            name: "SignalDispatchers",
            dependencies: ["Descriptors", "FreeBSDKit", "CSignal"]
        ),
        .target(
            name: "FPC",
            dependencies: ["Capabilities", "Descriptors", "Capsicum", "FreeBSDKit"]
        ),
        .testTarget(
            name: "CapsicumTests",
            dependencies: ["Capsicum"]
        ),
        .testTarget(
            name: "CCapsicumTests",
            dependencies: ["CCapsicum"]
        ),
        .testTarget(
            name: "JailsTests",
            dependencies: ["Jails"]
        ),
        .testTarget(
            name: "CapabilitiesTests",
            dependencies: ["Capabilities"]
        ),
        .testTarget(
            name: "DescriptorsTests",
            dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        ),
        .testTarget(
            name: "SignalDispatchersTests",
            dependencies: ["SignalDispatchers", "Descriptors", "FreeBSDKit"]
        ),
        .testTarget(
            name: "FreeBSDKitTests",
            dependencies: ["FreeBSDKit"]
        ),
        .testTarget(
            name: "FPCTests",
            dependencies: ["FPC", "Capabilities", "Descriptors"]
        ),
        .target(
            name: "MacLabel",
            dependencies: ["FreeBSDKit", "Capabilities", "Descriptors"]
        ),
        .target(
            name: "CMacLabelParser",
            path: "Sources/CMacLabelParser",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "MacLabelTests",
            dependencies: ["MacLabel"]
        ),
        .testTarget(
            name: "CasperTests",
            dependencies: ["Casper"]
        ),
        .executableTarget(
            name: "TestTool",
            dependencies: ["Capsicum", "Descriptors"]
        ),
        .executableTarget(
            name: "maclabel",
            dependencies: [
                "MacLabel",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/mac-policy-cli"
        ),
        .executableTarget(
            name: "fpc-test-harness",
            dependencies: ["FPC", "Capabilities", "Descriptors"],
            path: "Sources/fpc-test-harness"
        )

    ]
)
