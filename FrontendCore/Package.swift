// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FrontendCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LocalFileBrowserCore", targets: ["LocalFileBrowserCore"]),
        .library(name: "FavoriteTrackCore", targets: ["FavoriteTrackCore"]),
        .library(name: "PlaylistIdentityCore", targets: ["PlaylistIdentityCore"]),
        .library(name: "PlaylistTabsPersistenceCore", targets: ["PlaylistTabsPersistenceCore"]),
        .library(name: "FavoriteStoreCore", targets: ["FavoriteStoreCore"]),
        .library(name: "PlaybackHistoryCore", targets: ["PlaybackHistoryCore"]),
        .library(name: "FrontendPreferencesCore", targets: ["FrontendPreferencesCore"]),
        .library(name: "PlaybackRequestCore", targets: ["PlaybackRequestCore"]),
        .library(name: "PlaybackQueueCore", targets: ["PlaybackQueueCore"]),
        .library(name: "PlaybackTransportCore", targets: ["PlaybackTransportCore"]),
        .library(name: "FrontendStartupCore", targets: ["FrontendStartupCore"]),
        .library(name: "ArchiveCacheCore", targets: ["ArchiveCacheCore"]),
        .library(name: "ArchiveMaterializationCore", targets: ["ArchiveMaterializationCore"])
    ],
    dependencies: [
        .package(path: "../VGMBoy"),
        .package(name: "UACWrapper", path: "../UACMan/Wrapper")
    ],
    targets: [
        .target(name: "LocalFileBrowserCore"),
        .target(name: "FavoriteTrackCore"),
        .target(name: "PlaylistIdentityCore"),
        .target(name: "PlaylistTabsPersistenceCore"),
        .target(
            name: "FavoriteStoreCore",
            dependencies: ["FavoriteTrackCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(name: "PlaybackHistoryCore", dependencies: ["FavoriteStoreCore"]),
        .target(name: "FrontendPreferencesCore"),
        .target(name: "PlaybackRequestCore"),
        .target(name: "PlaybackQueueCore", dependencies: ["PlaybackRequestCore"]),
        .target(name: "FrontendStartupCore"),
        .target(name: "ArchiveCacheCore"),
        .target(
            name: "ArchiveMaterializationCore",
            dependencies: [
                "ArchiveCacheCore",
                .product(name: "VGMBoyArchiveCore", package: "VGMBoy"),
                .product(name: "UACWrapperCore", package: "UACWrapper")
            ]
        ),
        .target(
            name: "PlaybackTransportCore",
            dependencies: [
                "PlaybackRequestCore",
                "PlaybackQueueCore",
                .product(name: "VGMBoyKit", package: "VGMBoy")
            ]
        ),
        .testTarget(name: "LocalFileBrowserCoreTests", dependencies: ["LocalFileBrowserCore"]),
        .testTarget(name: "FavoriteTrackCoreTests", dependencies: ["FavoriteTrackCore"]),
        .testTarget(name: "PlaylistIdentityCoreTests", dependencies: ["PlaylistIdentityCore"]),
        .testTarget(name: "FavoriteStoreCoreTests", dependencies: ["FavoriteStoreCore"]),
        .testTarget(name: "FrontendPreferencesCoreTests", dependencies: ["FrontendPreferencesCore"]),
        .testTarget(name: "PlaybackRequestCoreTests", dependencies: ["PlaybackRequestCore"]),
        .testTarget(name: "PlaybackQueueCoreTests", dependencies: ["PlaybackQueueCore"]),
        .testTarget(name: "PlaybackTransportCoreTests", dependencies: ["PlaybackTransportCore"]),
        .testTarget(name: "ArchiveCacheCoreTests", dependencies: ["ArchiveCacheCore"]),
        .testTarget(name: "ArchiveMaterializationCoreTests", dependencies: ["ArchiveMaterializationCore"])
    ],
    swiftLanguageModes: [.v6]
)
