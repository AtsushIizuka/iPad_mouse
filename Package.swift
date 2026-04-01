// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iPadMouse",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]
        )
    ],
    targets: [
        .target(
            name: "SharedCore",
            path: "Sources/SharedCore"
        ),
        .testTarget(
            name: "SharedCoreTests",
            dependencies: ["SharedCore"],
            path: "Tests/SharedCoreTests"
        )
    ]
)
