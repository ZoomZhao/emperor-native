// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EmperorNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "EmperorCore", targets: ["EmperorCore"]),
        .library(name: "EmperorGameplay", targets: ["EmperorGameplay"]),
        .executable(name: "emperor-inspect", targets: ["EmperorInspector"]),
        .executable(name: "EmperorNative", targets: ["EmperorNative"]),
        .executable(name: "emperor-ui-smoke", targets: ["EmperorNativeUISmoke"])
    ],
    targets: [
        .systemLibrary(
            name: "CZlib",
            path: "Sources/CZlib"
        ),
        .target(
            name: "EmperorCore",
            dependencies: ["CZlib"],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "EmperorInspector",
            dependencies: ["EmperorCore"]
        ),
        .target(
            name: "EmperorGameplay",
            dependencies: ["EmperorCore"]
        ),
        .executableTarget(
            name: "EmperorNative",
            dependencies: ["EmperorCore", "EmperorGameplay"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation")
            ]
        ),
        .executableTarget(
            name: "EmperorNativeUISmoke",
            dependencies: ["EmperorGameplay"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "EmperorCoreTests",
            dependencies: ["EmperorCore"]
        ),
        .testTarget(
            name: "EmperorGameplayTests",
            dependencies: ["EmperorGameplay", "EmperorCore"]
        )
    ]
)
