// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MetaMan",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "MetaManCore", targets: ["MetaManCore"]),
        .executable(name: "metaman", targets: ["metaman"])
    ],
    dependencies: [
        .package(name: "UACWrapper", path: "../UACMan/Wrapper")
    ],
    targets: [
        .target(
            name: "MetaManZlib",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("z")]
        ),
        // Format readers are discovered as one MetaManCore source set; keep
        // format registration and byte-layout ownership inside that target.
        .target(
            name: "MetaManCore",
            dependencies: [
                "MetaManZlib",
                .product(name: "UACWrapperCore", package: "UACWrapper")
            ]
        ),
        .executableTarget(name: "metaman", dependencies: ["MetaManCore"]),
        .testTarget(
            name: "MetaManCoreTests",
            dependencies: [
                "MetaManCore",
                .product(name: "UACWrapperCore", package: "UACWrapper")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
