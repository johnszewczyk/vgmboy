// swift-tools-version: 6.1

import Foundation
import PackageDescription

// VGMBoy is the shared upstream source and dependency garden. Frontends link
// VGMBoyKit or call its narrow process boundary; they do not build decoders.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let dependencyRoot = "\(packageRoot)/.build/dependencies"
let sharedVendorRoot = "\(packageRoot)/vendor"
let libVGMVendorDirectory = "\(sharedVendorRoot)/libvgm"
let libVGMBuildDirectory = "\(dependencyRoot)/libvgm"
let libMGBAVendorDirectory = "\(sharedVendorRoot)/mgba"
let libMGBABuildDirectory = "\(dependencyRoot)/mgba"
let twoSFVendorDirectory = "\(sharedVendorRoot)/2sf2wav"
let twoSFBuildDirectory = "\(dependencyRoot)/2sf"
let vgmstreamVendorDirectory = "\(sharedVendorRoot)/vgmstream/src"
let vgmstreamBuildDirectory = "\(dependencyRoot)/vgmstream"
let lazyUSFVendorDirectory = "\(sharedVendorRoot)/lazyusf2"
let lazyUSFBuildDirectory = "\(dependencyRoot)/lazyusf"
let playPSFBuildDirectory = "\(dependencyRoot)/play-psf"
let playPSFVendorDirectory = "\(sharedVendorRoot)/play/tools/PsfPlayer/Source"

let package = Package(
    name: "VGMBoy",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "VGMBoyKit", targets: ["VGMBoyKit"]),
        .executable(name: "vgmboy-cli", targets: ["vgmboy"]),
        .executable(name: "vgmboy-electron-bridge", targets: ["VGMBoyElectronBridge"]),
        .executable(name: "vgmboy-highly-complete-inspect", targets: ["VGMBoyHighlyCompleteInspect"]),
        .executable(name: "VGMBoy", targets: ["VGMBoyApp"])
    ],
    targets: [
        .systemLibrary(
            name: "VGMBoyCGameMusicEmu",
            path: "Sources/CGameMusicEmu",
            pkgConfig: "libgme",
            providers: [.brew(["game-music-emu"])]
        ),
        .target(
            name: "VGMBoyCLibVGM",
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
            name: "VGMBoyCHighlyComplete",
            path: "Sources/CHighlyComplete",
            publicHeadersPath: "include",
            cSettings: [
                .define("M_CORE_GBA"),
                .define("ENABLE_VFS"),
                .define("ENABLE_DIRECTORIES"),
                .unsafeFlags([
                    "-I\(libMGBAVendorDirectory)/include",
                    "-I\(libMGBABuildDirectory)/include",
                    "-I\(libMGBAVendorDirectory)/src"
                ])
            ],
            cxxSettings: [
                .define("M_CORE_GBA"),
                .define("ENABLE_VFS"),
                .define("ENABLE_DIRECTORIES"),
                .unsafeFlags([
                    "-I\(libMGBAVendorDirectory)/include",
                    "-I\(libMGBABuildDirectory)/include",
                    "-I\(libMGBAVendorDirectory)/src"
                ])
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(libMGBABuildDirectory)", "-lmgba"]),
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "VGMBoyC2SF",
            path: "Sources/C2SF",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags([
                    "-I\(twoSFVendorDirectory)",
                    "-I\(twoSFVendorDirectory)/desmume",
                    "-I\(twoSFVendorDirectory)/sseqplayer"
                ])
            ],
            linkerSettings: [
                .unsafeFlags(["\(twoSFBuildDirectory)/lib2sf.a"]),
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "VGMBoyCVGmstream",
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
            name: "VGMBoyCFFmpeg",
            path: "Sources/CFFmpeg",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/opt/homebrew/opt/ffmpeg/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/opt/ffmpeg/lib"]),
                .linkedLibrary("avcodec"),
                .linkedLibrary("avformat"),
                .linkedLibrary("avutil"),
                .linkedLibrary("swresample")
            ]
        ),
        .target(
            name: "VGMBoyCLazyUSF",
            path: "Sources/CLazyUSF",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags([
                    "-I\(lazyUSFVendorDirectory)",
                    "-I\(sharedVendorRoot)/psflib"
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
            name: "VGMBoyCPlayPSF",
            path: "Sources/CPlayPSF",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags([
                    "-std=c++17",
                    "-I\(playPSFVendorDirectory)",
                    "-I\(sharedVendorRoot)/play/Source",
                    "-I\(sharedVendorRoot)/play/Source/app_shared",
                    "-I\(sharedVendorRoot)/play/deps/CodeGen/src",
                    "-I\(sharedVendorRoot)/play/deps/CodeGen/include",
                    "-I\(sharedVendorRoot)/play/deps/Framework/include",
                    "-I\(sharedVendorRoot)/play/deps/Dependencies/ghc_filesystem/include"
                ])
            ],
            linkerSettings: [
                .unsafeFlags(["\(playPSFBuildDirectory)/libcocoaspice_play_psf.a"]),
                .linkedLibrary("z"),
                .linkedLibrary("bz2")
            ]
        ),
        .target(
            name: "VGMBoyCSIDPlayFP",
            path: "Sources/CSIDPlayFP",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++17", "-I/opt/homebrew/opt/libsidplayfp/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/opt/libsidplayfp/lib"]),
                .linkedLibrary("sidplayfp")
            ]
        ),
        .target(
            name: "VGMBoyCOpenMPT",
            path: "Sources/COpenMPT",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/opt/homebrew/opt/libopenmpt/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/opt/libopenmpt/lib"]),
                .linkedLibrary("openmpt")
            ]
        ),
        .target(
            name: "VGMBoyCAudioUnit",
            path: "Sources/CAudioUnit",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("AudioToolbox")]
        ),
        .target(
            name: "VGMBoyKit",
            dependencies: ["VGMBoyCGameMusicEmu", "VGMBoyCLibVGM", "VGMBoyCHighlyComplete", "VGMBoyC2SF", "VGMBoyCVGmstream", "VGMBoyCFFmpeg", "VGMBoyCLazyUSF", "VGMBoyCPlayPSF", "VGMBoyCSIDPlayFP", "VGMBoyCOpenMPT", "VGMBoyCAudioUnit"],
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
            name: "VGMBoyElectronBridge",
            dependencies: ["VGMBoyKit"]
        ),
        .executableTarget(
            name: "VGMBoyHighlyCompleteInspect",
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
