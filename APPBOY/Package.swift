// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "APPBOY",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "APPBOY", targets: ["APPBOY"])
    ],
    targets: [
        .executableTarget(
            name: "APPBOY",
            resources: [.copy("Resources/WebUI")],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
