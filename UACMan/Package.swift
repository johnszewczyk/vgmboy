// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "UACMan",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UACManCore", targets: ["UACManCore"]),
        .executable(name: "UACManApp", targets: ["UACManApp"]),
        .executable(name: "UACManMetadataCLI", targets: ["UACManMetadataCLI"])
    ],
    dependencies: [
        .package(name: "UACWrapper", path: "Wrapper"),
        .package(path: "../MetaMan")
    ],
    targets: [
        .target(
            name: "UACManCore",
            dependencies: [
                .product(name: "UACWrapperCore", package: "UACWrapper"),
                .product(name: "MetaManCore", package: "MetaMan")
            ],
            path: "Application/Sources/UACManCore"
        ),
        .executableTarget(
            name: "UACManApp",
            dependencies: [
                "UACManCore",
                .product(name: "UACWrapperCore", package: "UACWrapper"),
                .product(name: "MetaManCore", package: "MetaMan")
            ],
            path: "Application/Sources/UACManApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "UACManMetadataCLI",
            dependencies: [
                "UACManCore",
                .product(name: "UACWrapperCore", package: "UACWrapper")
            ],
            path: "Application/Sources/UACManMetadataCLI"
        ),
        .testTarget(
            name: "UACManCoreTests",
            dependencies: [
                "UACManCore",
                .product(name: "UACWrapperCore", package: "UACWrapper"),
                .product(name: "MetaManCore", package: "MetaMan")
            ],
            path: "Application/Tests/UACManCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
