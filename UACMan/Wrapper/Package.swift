// swift-tools-version: 6.3

import PackageDescription

var packageDependencies: [Package.Dependency] = []
var coreDependencies: [Target.Dependency] = []

#if os(Linux)
packageDependencies.append(
    .package(
        url: "https://github.com/apple/swift-crypto.git",
        "4.0.0" ..< "5.0.0"
    )
)
coreDependencies.append(.product(name: "Crypto", package: "swift-crypto"))
#endif

let package = Package(
    name: "UACWrapper",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "UACWrapperCore", targets: ["UACWrapperCore"])
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "UACWrapperCore",
            dependencies: coreDependencies,
            path: "Sources/UACWrapperCore"
        ),
        .testTarget(
            name: "UACWrapperCoreTests",
            dependencies: ["UACWrapperCore"],
            path: "Tests/UACWrapperCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
