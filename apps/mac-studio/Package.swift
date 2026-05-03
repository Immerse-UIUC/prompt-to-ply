// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PromptToPLYCLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "prompt-to-ply",
            targets: ["PromptToPLYCLI"]
        )
    ],
    dependencies: [
        .package(path: "../../packages/job-core"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "PromptToPLYCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "JobCore", package: "job-core")
            ]
        ),
        .testTarget(
            name: "PromptToPLYCLITests",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "JobCore", package: "job-core"),
                "PromptToPLYCLI"
            ]
        )
    ]
)
