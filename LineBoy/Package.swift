// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "LineBoy",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "LineBoy", targets: ["LineBoy"])
    ],
    dependencies: [
        .package(path: "../CatalogReader"),
        .package(path: "../FrontendCore"),
        .package(path: "../VGMBoy")
    ],
    targets: [
        .executableTarget(
            name: "LineBoy",
            dependencies: [
                .product(name: "CatalogBrowserCore", package: "CatalogReader"),
                .product(name: "CatalogReader", package: "CatalogReader"),
                .product(name: "CatalogPlaylistCore", package: "CatalogReader"),
                .product(name: "ArchiveCacheCore", package: "FrontendCore"),
                .product(name: "ArchiveMaterializationCore", package: "FrontendCore"),
                .product(name: "FavoriteStoreCore", package: "FrontendCore"),
                .product(name: "FavoriteTrackCore", package: "FrontendCore"),
                .product(name: "PlaylistTabsPersistenceCore", package: "FrontendCore"),
                .product(name: "PlaybackQueueCore", package: "FrontendCore"),
                .product(name: "PlaybackTransportCore", package: "FrontendCore"),
                .product(name: "VGMBoyFormatCore", package: "VGMBoy"),
                .product(name: "VGMBoyKit", package: "VGMBoy")
            ],
            path: ".",
            exclude: ["AGENTS.md", "README.md", "ai", "app-info.plist", "build.sh", "launch.sh"],
            sources: ["Sources/LineBoy"],
            resources: [
                .copy("index.html"),
                .copy("assets")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
