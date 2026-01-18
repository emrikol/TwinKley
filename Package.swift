// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TwinKley",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TwinKley", targets: ["TwinKley"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        // Core library with testable code
        .target(
            name: "TwinKleyCore",
            path: "Sources/Core"
        ),
        // Main executable
        .executableTarget(
            name: "TwinKley",
            dependencies: [
                "TwinKleyCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/App"
        ),
        // Unit tests
        .testTarget(
            name: "TwinKleyTests",
            dependencies: ["TwinKleyCore"],
            path: "Tests"
        )
    ]
)
