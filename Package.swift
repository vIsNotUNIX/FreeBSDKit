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
        .executable(
            name: "testtool",
            targets: ["TestTool"]
        )
    ],
    targets: [
        .target(
            name: "FreeBSDKit"
        ),
        .target(
            name: "CCapsicum",
            path: "Sources/CCapsicum"
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
            dependencies: ["CJails"],
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
            name: "Descriptors",
            dependencies: [
                "Capsicum", "CProcessDescriptor", 
                "CEventDescriptor", "CJails", "Jails",
                "CINotify"
            ]
        ),
        .target(
            name: "Capabilities",
            dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        ),
        .target(
            name: "SignalDispatchers",
            dependencies: ["Descriptors", "FreeBSDKit"]
        ),
        .testTarget(
            name: "CapsicumTests",
            dependencies: ["Capsicum"]
        ),
        .testTarget(
            name: "CCapsicumTests",
            dependencies: ["CCapsicum"]
        ),
        // .testTarget(
        //     name: "DescriptorsTests",
        //     dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        // ),
        // .testTarget(
        //     name: "FreeBSDKitTests",
        //     dependencies: ["FreeBSDKit"]
        // ),
        .executableTarget(
            name: "TestTool",
            dependencies: ["Capsicum", "Descriptors"]
        )

    ]
)
