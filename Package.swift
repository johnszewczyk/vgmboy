// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SPCBoyWK",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "SPCBoyWK", targets: ["SPCBoyWK"])
    ],
    dependencies: [
        .package(path: "../CatalogReader"),
        .package(path: "../VGMBoy")
    ],
    targets: [
        .executableTarget(
            name: "SPCBoyWK",
            dependencies: [
                .product(name: "CatalogBrowserCore", package: "CatalogReader"),
                .product(name: "FrontendCommandCore", package: "CatalogReader"),
                .product(name: "CatalogReader", package: "CatalogReader"),
                .product(name: "VGMBoyKit", package: "VGMBoy"),
                .product(name: "VGMBoyEndpointCore", package: "VGMBoy")
            ],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
