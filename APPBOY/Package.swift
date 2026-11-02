// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "APPBOY",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "APPBOY", targets: ["APPBOY"])
    ],
    dependencies: [
        .package(path: "../CatalogReader"),
        .package(path: "../FrontendCore"),
        .package(path: "../UACMan/Wrapper"),
        .package(path: "../VGMBoy")
    ],
    targets: [
        .executableTarget(
            name: "APPBOY",
            dependencies: [
                .product(name: "CatalogReader", package: "CatalogReader"),
                .product(name: "CatalogPlaylistCore", package: "CatalogReader"),
                .product(name: "CatalogPlaylistPresentationCore", package: "CatalogReader"),
                .product(name: "CatalogBrowserCore", package: "CatalogReader"),
                .product(name: "CatalogGalleryCore", package: "CatalogReader"),
                .product(name: "CatalogSessionCore", package: "CatalogReader"),
                .product(name: "FrontendCommandCore", package: "CatalogReader"),
                .product(name: "FavoriteTrackCore", package: "FrontendCore"),
                .product(name: "FavoriteStoreCore", package: "FrontendCore"),
                .product(name: "PlaybackHistoryCore", package: "FrontendCore"),
                .product(name: "PlaylistIdentityCore", package: "FrontendCore"),
                .product(name: "PlaylistTabsPersistenceCore", package: "FrontendCore"),
                .product(name: "FrontendPreferencesCore", package: "FrontendCore"),
                .product(name: "PlaybackQueueCore", package: "FrontendCore"),
                .product(name: "ArchiveCacheCore", package: "FrontendCore"),
                .product(name: "UACWrapperCore", package: "Wrapper"),
                .product(name: "VGMBoyFormatCore", package: "VGMBoy"),
                .product(name: "VGMBoyEndpointCore", package: "VGMBoy"),
                .product(name: "VGMBoyEmbeddedCore", package: "VGMBoy")
            ],
            resources: [.copy("Resources/WebUI")],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
