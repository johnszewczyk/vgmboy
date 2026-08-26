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
        .package(path: "../FrontendCore"),
        .package(path: "../VGMBoy")
    ],
    targets: [
        .executableTarget(
            name: "SPCBoyWK",
            dependencies: [
                .product(name: "CatalogBrowserCore", package: "CatalogReader"),
                .product(name: "FrontendCommandCore", package: "CatalogReader"),
                .product(name: "CatalogReader", package: "CatalogReader"),
                .product(name: "CatalogPlaylistCore", package: "CatalogReader"),
                .product(name: "CatalogSessionCore", package: "CatalogReader"),
                .product(name: "ArchiveCacheCore", package: "FrontendCore"),
                .product(name: "ArchiveMaterializationCore", package: "FrontendCore"),
                .product(name: "LocalFileBrowserCore", package: "FrontendCore"),
                .product(name: "FavoriteTrackCore", package: "FrontendCore"),
                .product(name: "PlaylistIdentityCore", package: "FrontendCore"),
                .product(name: "FavoriteStoreCore", package: "FrontendCore"),
                .product(name: "FrontendPreferencesCore", package: "FrontendCore"),
                .product(name: "PlaybackRequestCore", package: "FrontendCore"),
                .product(name: "PlaybackQueueCore", package: "FrontendCore"),
                .product(name: "PlaybackTransportCore", package: "FrontendCore"),
                .product(name: "VGMBoyFormatCore", package: "VGMBoy"),
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
