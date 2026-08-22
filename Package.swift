// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CatalogReader",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CatalogReader", targets: ["CatalogReader"]),
        .library(name: "CatalogBrowserCore", targets: ["CatalogBrowserCore"]),
        .executable(name: "catalog-reader-electron-bridge", targets: ["CatalogReaderElectronBridge"])
    ],
    targets: [
        .target(name: "CatalogReader", linkerSettings: [.linkedLibrary("sqlite3")]),
        .target(name: "CatalogBrowserCore", dependencies: ["CatalogReader"]),
        .executableTarget(name: "CatalogReaderElectronBridge", dependencies: ["CatalogReader"]),
        .testTarget(name: "CatalogReaderTests", dependencies: ["CatalogReader"], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "CatalogBrowserCoreTests", dependencies: ["CatalogBrowserCore"])
    ],
    swiftLanguageModes: [.v6]
)
