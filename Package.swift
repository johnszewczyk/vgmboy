// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CatalogReader",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CatalogReader", targets: ["CatalogReader"]),
        .library(name: "CatalogPlaylistCore", targets: ["CatalogPlaylistCore"]),
        .library(name: "CatalogBrowserCore", targets: ["CatalogBrowserCore"]),
        .library(name: "CatalogSessionCore", targets: ["CatalogSessionCore"]),
        .library(name: "FrontendCommandCore", targets: ["FrontendCommandCore"]),
        .executable(name: "catalog-reader-electron-bridge", targets: ["CatalogReaderElectronBridge"])
    ],
    targets: [
        .target(name: "CatalogReader", linkerSettings: [.linkedLibrary("sqlite3")]),
        .target(name: "CatalogPlaylistCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .target(name: "CatalogBrowserCore", dependencies: ["CatalogReader"]),
        .target(name: "CatalogSessionCore", dependencies: ["CatalogReader"]),
        .target(name: "FrontendCommandCore"),
        .executableTarget(name: "CatalogReaderElectronBridge", dependencies: ["CatalogReader"]),
        .testTarget(name: "CatalogReaderTests", dependencies: ["CatalogReader", "CatalogPlaylistCore"], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "CatalogBrowserCoreTests", dependencies: ["CatalogBrowserCore"]),
        .testTarget(name: "CatalogSessionCoreTests", dependencies: ["CatalogSessionCore"]),
        .testTarget(name: "FrontendCommandCoreTests", dependencies: ["FrontendCommandCore"])
    ],
    swiftLanguageModes: [.v6]
)
