// swift-tools-version:5.9
import PackageDescription

// Size optimization settings for release builds
// These reduce binary size by ~20-30% with minimal runtime impact
let sizeOptimizationSettings: [SwiftSetting] = [
    // Optimize for size over speed (smaller code, slightly slower)
    .unsafeFlags(["-Osize"], .when(configuration: .release)),
    // Remove reflection metadata (Mirror, etc.) - not needed for this app
    .unsafeFlags(["-Xfrontend", "-disable-reflection-metadata"], .when(configuration: .release)),
]

let package = Package(
    name: "TwinKley",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TwinKley", targets: ["TwinKley"]),
        // Dynamic library for UI components (loaded on-demand)
        .library(name: "TwinKleyUI", type: .dynamic, targets: ["TwinKleyUI"])
    ],
    dependencies: [
        // Local package for core types (dynamic library, shared between main and UI)
        .package(path: "Packages/TwinKleyCore"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        // UI library (debug window, preferences, about) - loaded dynamically
        .target(
            name: "TwinKleyUI",
            dependencies: [
                .product(name: "TwinKleyCore", package: "TwinKleyCore")
            ],
            path: "Sources/UI",
            swiftSettings: [
                .define("TWINKLEY_UI_MODULE")
            ] + sizeOptimizationSettings
        ),
        // Main executable (minimal - loads UI on demand)
        .executableTarget(
            name: "TwinKley",
            dependencies: [
                .product(name: "TwinKleyCore", package: "TwinKleyCore"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/App",
            swiftSettings: sizeOptimizationSettings
        ),
        // Unit tests (no size optimization - need debug symbols)
        .testTarget(
            name: "TwinKleyTests",
            dependencies: [
                .product(name: "TwinKleyCore", package: "TwinKleyCore")
            ],
            path: "Tests"
        )
    ]
)
