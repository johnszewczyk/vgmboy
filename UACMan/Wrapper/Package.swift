// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "UACWrapper",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UACWrapperCore", targets: ["UACWrapperCore"])
    ],
    targets: [
        .target(name: "UACWrapperCore", path: "Sources/UACWrapperCore"),
        .testTarget(
            name: "UACWrapperCoreTests",
            dependencies: ["UACWrapperCore"],
            path: "Tests/UACWrapperCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
