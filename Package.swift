// swift-tools-version: 5.10
// The FreeBSD ports tree still uses 5.10. You can build with 6.2

import PackageDescription

let package = Package(
    name: "FreeBSDKit",
    products: [
        // Reserved. The Swift project hasn't decided on `import FreeBSD`
        // or `import Glibc`, or something else longterm for expsing libc. If we 
        // can't come to consensues in 2026 we will expose a `libc` overlay here.
        // .library(
        //     name: "FreeBSDKit",
        //     targets: ["FreeBSDKit"]
        // ),
        .library(
            name: "Capsicum",
            targets: ["Capsicum"]
        ),
        .library(
            name: "CCapsicum",
            targets: ["CCapsicum"]
        ),
        .library(
            name: "Descriptors",
            targets: ["Descriptors"]
        ),
        .library(
            name: "CProcessDescriptor",
            targets: ["CProcessDescriptor"]
        ),
        .library(
            name: "CEventDescriptor",
            targets: ["CEventDescriptor"]
        ),
        .executable(
            name: "testtool",
            targets: ["TestTool"]
        )
    
    ],
    targets: [
        // Reserved. See above.
        .target(
            name: "FreeBSDKit"
        ),
        // .testTarget(
        //     name: "FreeBSDKitTests",
        //     dependencies: ["FreeBSDKit"]
        // ),
        .target(
            name: "CCapsicum",
            path: "Sources/CCapsicum"
        ),
        .target(
            name: "Capsicum",
            dependencies: ["CCapsicum", "FreeBSDKit"]
        ),
        .testTarget(
            name: "CapsicumTests",
            dependencies: ["Capsicum"]
        ),
        .testTarget(
            name: "CCapsicumTests",
            dependencies: ["CCapsicum"]
        ),
        .target(
            name: "CProcessDescriptor",
            path: "Sources/CProcessDescriptor"
        ),
        .target(
            name: "CEventDescriptor",
            path: "Sources/CEventDescriptor"
        ),
        .target(
            name: "Descriptors",
            dependencies: ["Capsicum", "CProcessDescriptor", "CEventDescriptor"]
        ),
        .testTarget(
            name: "DescriptorsTests",
            dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        ),
        .target(
            name: "Capabilities",
            dependencies: ["Capsicum", "CProcessDescriptor", "Descriptors"]
        ),
        .executableTarget(
            name: "TestTool",
            dependencies: ["Capsicum", "Descriptors"]
        )

    ]
)
