// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FrontendCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ArchiveMaterializationCore", targets: ["ArchiveMaterializationCore"]),
        .library(name: "ArchiveCacheCore", targets: ["ArchiveCacheCore"]),
        .library(name: "LocalFileBrowserCore", targets: ["LocalFileBrowserCore"]),
        .library(name: "FavoriteTrackCore", targets: ["FavoriteTrackCore"]),
        .library(name: "PlaylistIdentityCore", targets: ["PlaylistIdentityCore"]),
        .library(name: "FavoriteStoreCore", targets: ["FavoriteStoreCore"]),
        .library(name: "FrontendPreferencesCore", targets: ["FrontendPreferencesCore"]),
        .library(name: "PlaybackRequestCore", targets: ["PlaybackRequestCore"]),
        .library(name: "PlaybackQueueCore", targets: ["PlaybackQueueCore"]),
        .library(name: "PlaybackTransportCore", targets: ["PlaybackTransportCore"])
    ],
    dependencies: [
        .package(path: "../VGMBoy")
    ],
    targets: [
        .target(
            name: "ArchiveMaterializationCore",
            dependencies: [
                "ArchiveCacheCore",
                .product(name: "VGMBoyFormatCore", package: "VGMBoy")
            ]
        ),
        .target(name: "ArchiveCacheCore"),
        .target(name: "LocalFileBrowserCore"),
        .target(name: "FavoriteTrackCore"),
        .target(name: "PlaylistIdentityCore"),
        .target(
            name: "FavoriteStoreCore",
            dependencies: ["FavoriteTrackCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(name: "FrontendPreferencesCore"),
        .target(name: "PlaybackRequestCore"),
        .target(name: "PlaybackQueueCore", dependencies: ["PlaybackRequestCore"]),
        .target(
            name: "PlaybackTransportCore",
            dependencies: [
                "PlaybackRequestCore",
                "PlaybackQueueCore",
                .product(name: "VGMBoyKit", package: "VGMBoy")
            ]
        ),
        .testTarget(name: "ArchiveMaterializationCoreTests", dependencies: ["ArchiveMaterializationCore"]),
        .testTarget(name: "ArchiveCacheCoreTests", dependencies: ["ArchiveCacheCore"]),
        .testTarget(name: "LocalFileBrowserCoreTests", dependencies: ["LocalFileBrowserCore"]),
        .testTarget(name: "FavoriteTrackCoreTests", dependencies: ["FavoriteTrackCore"]),
        .testTarget(name: "PlaylistIdentityCoreTests", dependencies: ["PlaylistIdentityCore"]),
        .testTarget(name: "FavoriteStoreCoreTests", dependencies: ["FavoriteStoreCore"]),
        .testTarget(name: "FrontendPreferencesCoreTests", dependencies: ["FrontendPreferencesCore"]),
        .testTarget(name: "PlaybackRequestCoreTests", dependencies: ["PlaybackRequestCore"]),
        .testTarget(name: "PlaybackQueueCoreTests", dependencies: ["PlaybackQueueCore"]),
        .testTarget(name: "PlaybackTransportCoreTests", dependencies: ["PlaybackTransportCore"])
    ],
    swiftLanguageModes: [.v6]
)
