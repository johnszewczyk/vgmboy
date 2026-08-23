// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FrontendCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ArchiveMaterializationCore", targets: ["ArchiveMaterializationCore"]),
        .library(name: "LocalFileBrowserCore", targets: ["LocalFileBrowserCore"]),
        .library(name: "FavoriteTrackCore", targets: ["FavoriteTrackCore"])
    ],
    targets: [
        .target(name: "ArchiveMaterializationCore"),
        .target(name: "LocalFileBrowserCore"),
        .target(name: "FavoriteTrackCore"),
        .testTarget(name: "ArchiveMaterializationCoreTests", dependencies: ["ArchiveMaterializationCore"]),
        .testTarget(name: "LocalFileBrowserCoreTests", dependencies: ["LocalFileBrowserCore"]),
        .testTarget(name: "FavoriteTrackCoreTests", dependencies: ["FavoriteTrackCore"])
    ],
    swiftLanguageModes: [.v6]
)
