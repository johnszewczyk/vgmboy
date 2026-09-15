// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "UACMan",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "UACManCore", targets: ["UACManCore"]),
        .executable(name: "UACManApp", targets: ["UACManApp"])
    ],
    dependencies: [
        .package(path: "../FrontendCore"),
        .package(path: "../MetaMan")
    ],
    targets: [
        .target(
            name: "UACManCore",
            dependencies: [
                .product(name: "UACContainerCore", package: "FrontendCore"),
                .product(name: "MetaManCore", package: "MetaMan")
            ]
        ),
        .executableTarget(
            name: "UACManApp",
            dependencies: [
                "UACManCore",
                .product(name: "UACContainerCore", package: "FrontendCore"),
                .product(name: "MetaManCore", package: "MetaMan")
            ]
        ),
        .testTarget(
            name: "UACManCoreTests",
            dependencies: [
                "UACManCore",
                .product(name: "UACContainerCore", package: "FrontendCore"),
                .product(name: "MetaManCore", package: "MetaMan")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
