// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MetaMan",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "MetaManCore", targets: ["MetaManCore"]),
        .executable(name: "metaman", targets: ["metaman"])
    ],
    targets: [
        .target(name: "MetaManCore"),
        .executableTarget(name: "metaman", dependencies: ["MetaManCore"]),
        .testTarget(name: "MetaManCoreTests", dependencies: ["MetaManCore"])
    ],
    swiftLanguageModes: [.v6]
)
