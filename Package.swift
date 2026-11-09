// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sky",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SkyCore", path: "Sources/SkyCore"),
        .target(
            name: "SkyApp",
            dependencies: ["SkyCore"],
            path: "Sources/SkyApp"
        ),
        .executableTarget(
            name: "Sky",
            dependencies: ["SkyApp"],
            path: "Sources/Sky"
        ),
        // Renders the shelf and preview to PNGs without putting anything on screen.
        .executableTarget(
            name: "SkySnapshots",
            dependencies: ["SkyApp", "SkyCore"],
            path: "Sources/SkySnapshots"
        ),
        .testTarget(
            name: "SkyCoreTests",
            dependencies: ["SkyCore"],
            path: "Tests/SkyCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
