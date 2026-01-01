// swift-tools-version: 5.10
// The FreeBSD ports tree still uses 5.10. You can build with 6.2

import PackageDescription

let package = Package(
    name: "FreeBSDKit",
    products: [
        // Reserved. The Swift project hasn't decided on `import FreeBSD`
        // or `import Glibc`, or something else as expsing libc. If we 
        // can't come to consensues in 2026 we will expose a `libc` overlay
        // .library(
        //     name: "FreeBSDKit",
        //     targets: ["FreeBSDKit"]
        // ),
        .library(
            name: "Capsicum",
            targets: ["Capsicum"]
        )
    
    ],
    targets: [
        // Reserved. See above.
        // .target(
        //     name: "FreeBSDKit"
        // ),
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
            dependencies: ["CCapsicum"]
        )
    ]
)
