// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "TwinKleyCore",
	platforms: [.macOS(.v13)],
	products: [
		.library(name: "TwinKleyCore", type: .dynamic, targets: ["TwinKleyCore"])
	],
	targets: [
		.target(
			name: "TwinKleyCore",
			swiftSettings: [
				.unsafeFlags(["-Osize"], .when(configuration: .release)),
				.unsafeFlags(["-Xfrontend", "-disable-reflection-metadata"], .when(configuration: .release))
			]
		)
	]
)
