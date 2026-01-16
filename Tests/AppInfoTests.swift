@testable import TwinKleyCore
import XCTest

final class AppInfoTests: XCTestCase {
	func testVersionFormat() {
		// Version should be in semver format (x.y.z)
		let version = AppInfo.version
		let components = version.split(separator: ".")

		XCTAssertEqual(components.count, 3, "Version should have 3 components (major.minor.patch)")

		for component in components {
			XCTAssertNotNil(Int(component), "Each version component should be a number")
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
