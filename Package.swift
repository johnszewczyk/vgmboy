// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FrontendCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ArchiveMaterializationCore", targets: ["ArchiveMaterializationCore"]),
        .library(name: "LocalFileBrowserCore", targets: ["LocalFileBrowserCore"])
    ],
    targets: [
        .target(name: "ArchiveMaterializationCore"),
        .target(name: "LocalFileBrowserCore"),
        .testTarget(name: "ArchiveMaterializationCoreTests", dependencies: ["ArchiveMaterializationCore"]),
        .testTarget(name: "LocalFileBrowserCoreTests", dependencies: ["LocalFileBrowserCore"])
    ],
    swiftLanguageModes: [.v6]
)
