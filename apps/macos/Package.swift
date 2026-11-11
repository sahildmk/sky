// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sky",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Global shortcuts that need no special permission, and the control for recording them.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        .target(name: "SkyCore", path: "Sources/SkyCore"),
        .target(
            name: "SkyApp",
            dependencies: ["SkyCore", .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")],
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
        .testTarget(
            name: "SkyAppTests",
            dependencies: ["SkyApp", "SkyCore"],
            path: "Tests/SkyAppTests"
        ),
    ]
)
