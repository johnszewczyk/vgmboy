// swift-tools-version: 6.1

import Foundation
import PackageDescription

// libvgm is vendored and built by CocoaSpice (one upstream copy for the app
// family). VGMBoy links that build output rather than forking the library.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let cocoaspiceRoot = "\(packageRoot)/../CocoaSpice"
let libVGMVendorDirectory = "\(cocoaspiceRoot)/vendor/libvgm"
let libVGMBuildDirectory = "\(cocoaspiceRoot)/.build/libvgm"
let vgmstreamVendorDirectory = "\(cocoaspiceRoot)/vendor/vgmstream/src"
let vgmstreamBuildDirectory = "\(cocoaspiceRoot)/.build/vgmstream"
let lazyUSFVendorDirectory = "\(cocoaspiceRoot)/vendor/lazyusf2"
let lazyUSFBuildDirectory = "\(cocoaspiceRoot)/.build/lazyusf"

let package = Package(
    name: "VGMBoy",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "VGMBoyKit", targets: ["VGMBoyKit"]),
        .executable(name: "vgmboy-cli", targets: ["vgmboy"]),
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
            name: "CVGmstream",
            path: "Sources/CVGmstream",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-I\(vgmstreamVendorDirectory)", "-std=c++17"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "\(vgmstreamBuildDirectory)/src/libvgmstream.a",
                    "-L/opt/homebrew/opt/ffmpeg/lib",
                    "-L/opt/homebrew/opt/libvorbis/lib",
                    "-L/opt/homebrew/opt/libogg/lib"
                ]),
                .linkedLibrary("avcodec"),
                .linkedLibrary("avformat"),
                .linkedLibrary("avutil"),
                .linkedLibrary("swresample"),
                .linkedLibrary("vorbisfile"),
                .linkedLibrary("vorbis"),
                .linkedLibrary("ogg"),
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "CLazyUSF",
            path: "Sources/CLazyUSF",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags([
                    "-I\(lazyUSFVendorDirectory)",
                    "-I\(cocoaspiceRoot)/vendor/psflib"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "\(lazyUSFBuildDirectory)/liblazyusf.a",
                    "\(lazyUSFBuildDirectory)/libpsflib.a"
                ]),
                .linkedLibrary("z"),
                .linkedLibrary("m")
            ]
        ),
        .target(
            name: "VGMBoyKit",
            dependencies: ["CGameMusicEmu", "CLibVGM", "CVGmstream", "CLazyUSF"],
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