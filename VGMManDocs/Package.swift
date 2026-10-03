// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VGMManDocs",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "VGMManDocs", targets: ["VGMManDocs"])
    ],
    targets: [
        .executableTarget(
            name: "VGMManDocs",
            path: "Sources/VGMManDocs",
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("WebKit")]
        )
    ],
    swiftLanguageModes: [.v6]
)
