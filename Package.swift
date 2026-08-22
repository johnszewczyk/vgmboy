// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FrontendCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ArchiveMaterializationCore", targets: ["ArchiveMaterializationCore"])
    ],
    targets: [
        .target(name: "ArchiveMaterializationCore"),
        .testTarget(name: "ArchiveMaterializationCoreTests", dependencies: ["ArchiveMaterializationCore"])
    ],
    swiftLanguageModes: [.v6]
)
