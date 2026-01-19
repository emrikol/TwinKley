@testable import TwinKleyCore
import XCTest

/// Simple mock provider for testing UIContext
private struct MockProvider: PowerSourceProvider {
	func getPowerSourcesInfo() -> [[String: Any]]? { nil }
}

final class UIContextTests: XCTestCase {
	func testDefaultInit() {
		let context = UIContext()

		XCTAssertNil(context.brightnessMonitor)
		XCTAssertNil(context.displayProvider)
		XCTAssertNil(context.keyboardController)
		XCTAssertNil(context.syncManager)
		XCTAssertNil(context.settingsManager)
		XCTAssertNil(context.powerSourceProvider)
		XCTAssertNil(context.onDebugModeChanged)
		XCTAssertNil(context.onSyncHistoryToggled)
		XCTAssertNil(context.onSettingsChanged)
		XCTAssertNil(context.getAutoUpdateEnabled)
		XCTAssertNil(context.setAutoUpdateEnabled)
	}

	func testPowerSourceProviderAssignment() {
		let context = UIContext()

		context.powerSourceProvider = MockProvider()

		XCTAssertNotNil(context.powerSourceProvider)
	}

	func testCallbackAssignment() {
		let context = UIContext()
		var debugModeChangedCalled = false
		var syncHistoryToggledCalled = false
		var settingsChangedCalled = false

		context.onDebugModeChanged = { _ in debugModeChangedCalled = true }
		context.onSyncHistoryToggled = { _ in syncHistoryToggledCalled = true }
		context.onSettingsChanged = { settingsChangedCalled = true }

		// Verify callbacks are set
		XCTAssertNotNil(context.onDebugModeChanged)
		XCTAssertNotNil(context.onSyncHistoryToggled)
		XCTAssertNotNil(context.onSettingsChanged)

		// Invoke callbacks
		context.onDebugModeChanged?(true)
		context.onSyncHistoryToggled?(true)
		context.onSettingsChanged?()

		XCTAssertTrue(debugModeChangedCalled)
		XCTAssertTrue(syncHistoryToggledCalled)
		XCTAssertTrue(settingsChangedCalled)
	}

	func testAutoUpdateCallbacks() {
		let context = UIContext()
		var autoUpdateEnabled = false

		context.getAutoUpdateEnabled = { autoUpdateEnabled }
		context.setAutoUpdateEnabled = { autoUpdateEnabled = $0 }

		// Test get
		XCTAssertFalse(context.getAutoUpdateEnabled?() ?? true)

		// Test set
		context.setAutoUpdateEnabled?(true)
		XCTAssertTrue(context.getAutoUpdateEnabled?() ?? false)
	}

	func testDebugModeChangedCallback() {
		let context = UIContext()
		var receivedValue: Bool?

		context.onDebugModeChanged = { receivedValue = $0 }

		context.onDebugModeChanged?(true)
		XCTAssertEqual(receivedValue, true)

		context.onDebugModeChanged?(false)
		XCTAssertEqual(receivedValue, false)
	}

	func testSyncHistoryToggledCallback() {
		let context = UIContext()
		var receivedValue: Bool?

		context.onSyncHistoryToggled = { receivedValue = $0 }

		context.onSyncHistoryToggled?(true)
		XCTAssertEqual(receivedValue, true)

		context.onSyncHistoryToggled?(false)
		XCTAssertEqual(receivedValue, false)
	}
}
