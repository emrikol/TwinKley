@testable import TwinKleyCore
import XCTest

final class AppInfoTests: XCTestCase {
	func testVersionFormat() {
		// Version should be in semver format (x.y.z or x.y.z-prerelease)
		let version = AppInfo.version
		let components = version.split(separator: ".")

		XCTAssertEqual(components.count, 3, "Version should have 3 components (major.minor.patch)")

		// Major and minor must be numeric
		XCTAssertNotNil(Int(components[0]), "Major version should be a number")
		XCTAssertNotNil(Int(components[1]), "Minor version should be a number")

		// Patch can have pre-release suffix (e.g., "0-beta1")
		let patchParts = components[2].split(separator: "-", maxSplits: 1)
		XCTAssertNotNil(Int(patchParts[0]), "Patch version should be a number")

		// If there's a pre-release tag, it should be non-empty
		if patchParts.count > 1 {
			XCTAssertFalse(patchParts[1].isEmpty, "Pre-release tag should not be empty")
		}
	}

	func testAppName() {
		XCTAssertEqual(AppInfo.name, "☀️ TwinK[l]ey ⌨️")
		XCTAssertEqual(AppInfo.shortName, "TwinK[l]ey")
		XCTAssertFalse(AppInfo.name.isEmpty)
	}

	func testAppIdentifier() {
		XCTAssertEqual(AppInfo.identifier, "com.local.TwinKley")
		XCTAssertTrue(AppInfo.identifier.contains("."))
	}

	func testGitHubURL() {
		XCTAssertEqual(AppInfo.githubURL, "https://github.com/emrikol/TwinKley")
		XCTAssertTrue(AppInfo.githubURL.hasPrefix("https://"))
		XCTAssertTrue(AppInfo.githubURL.contains("github.com"))
	}
}
