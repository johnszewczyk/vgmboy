// swift-tools-version: 6.1

import Foundation
import PackageDescription

// libvgm is vendored and built by CocoaSpice (one upstream copy for the app
// family). VGMBoy links that build output rather than forking the library.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let cocoaspiceRoot = "\(packageRoot)/../CocoaSpice"
let libVGMVendorDirectory = "\(cocoaspiceRoot)/vendor/libvgm"
let libVGMBuildDirectory = "\(cocoaspiceRoot)/.build/libvgm"

let package = Package(
    name: "VGMBoy",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "VGMBoyKit", targets: ["VGMBoyKit"]),
        .executable(name: "vgmboy", targets: ["vgmboy"]),
        .executable(name: "VGMBoy", targets: ["VGMBoyApp"])
    ],
    targets: [
        .systemLibrary(
            name: "CGameMusicEmu",
            path: "Sources/CGameMusicEmu",
            pkgConfig: "libgme",
            providers: [.brew(["game-music-emu"])]
        ),
        .target(
            name: "CLibVGM",
            path: "Sources/CLibVGM",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-I\(libVGMVendorDirectory)"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(libVGMBuildDirectory)/bin",
                    "-lvgm-player",
                    "-lvgm-emu",
                    "-lvgm-utils"
                ]),
                .linkedLibrary("iconv"),
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "VGMBoyKit",
            dependencies: ["CGameMusicEmu", "CLibVGM"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "vgmboy",
            dependencies: ["VGMBoyKit"]
        ),
        .executableTarget(
            name: "VGMBoyApp",
            dependencies: ["VGMBoyKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "VGMBoyKitTests",
            dependencies: ["VGMBoyKit"],
            path: "Tests/VGMBoyKitTests"
        )
    ],
    swiftLanguageModes: [.v6]
)