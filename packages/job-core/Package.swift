// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JobCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "JobCore",
            targets: ["JobCore"]
        )
    ],
    targets: [
        .target(
            name: "JobCore"
        ),
        .testTarget(
            name: "JobCoreTests",
            dependencies: ["JobCore"]
        )
    ]
)
