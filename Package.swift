// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipManager",
            path: "Sources/ClipManager",
            exclude: [
                "Resources/Info.plist",
                "Resources/ClipManager.entitlements",
            ]
        ),
    ]
)
