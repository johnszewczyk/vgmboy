// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SPCBoyWK",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "SPCBoyWK", targets: ["SPCBoyWK"])
    ],
    dependencies: [
        .package(path: "../CatalogReader")
    ],
    targets: [
        .executableTarget(
            name: "SPCBoyWK",
            dependencies: [
                .product(name: "CatalogBrowserCore", package: "CatalogReader")
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
