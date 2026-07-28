// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlacPlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "CFLAC",
            pkgConfig: "flac",
            providers: [.brew(["flac"])]
        ),
        .target(
            name: "FlacPlayerCore",
            dependencies: ["CFLAC"]
        ),
        .executableTarget(
            name: "FlacPlayer",
            dependencies: ["FlacPlayerCore"],
            exclude: ["Info.plist", "Resources/AppIcon.icns"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/FlacPlayer/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "FlacPlayerCoreTests",
            dependencies: ["FlacPlayerCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
