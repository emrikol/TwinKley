@testable import TwinKleyCore
import XCTest

// MARK: - Mock Implementations

final class MockBrightnessProvider: BrightnessProvider {
	var brightnessToReturn: Float?
	var callCount = 0

	func getDisplayBrightness() -> Float? {
		callCount += 1
		return brightnessToReturn
	}
}

final class MockBrightnessController: BrightnessController {
	var lastSetBrightness: Float?
	var callCount = 0
	var shouldSucceed = true

	func setKeyboardBrightness(_ brightness: Float) -> Bool {
		callCount += 1
		lastSetBrightness = brightness
		return shouldSucceed
	}
}

// MARK: - Tests

final class BrightnessSyncManagerTests: XCTestCase {
	var provider: MockBrightnessProvider!
	var controller: MockBrightnessController!
	var syncManager: BrightnessSyncManager!

	override func setUp() {
		super.setUp()
		provider = MockBrightnessProvider()
		controller = MockBrightnessController()
		syncManager = BrightnessSyncManager(
			brightnessProvider: provider,
			brightnessController: controller
		)
	}

	// MARK: - Basic Sync Tests

	func testSyncWithLinearGamma() {
		provider.brightnessToReturn = 0.5

		let result = syncManager.sync(gamma: 1.0)

		XCTAssertTrue(result)
		XCTAssertEqual(controller.lastSetBrightness, 0.5)
		XCTAssertEqual(controller.callCount, 1)
		XCTAssertEqual(provider.callCount, 1)
	}

	func testSyncWithGammaCorrection() {
		provider.brightnessToReturn = 0.5

		let result = syncManager.sync(gamma: 2.0)

		XCTAssertTrue(result)
		// 0.5^2.0 = 0.25
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.25, accuracy: 0.001)
	}

	func testSyncWithGamma15() {
		provider.brightnessToReturn = 0.5

		let result = syncManager.sync(gamma: 1.5)

		XCTAssertTrue(result)
		// 0.5^1.5 ≈ 0.3536
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.3536, accuracy: 0.001)
	}

	func testSyncAtZeroBrightness() {
		provider.brightnessToReturn = 0.0

		let result = syncManager.sync(gamma: 2.2)

		XCTAssertTrue(result)
		XCTAssertEqual(controller.lastSetBrightness, 0.0)
	}

	func testSyncAtMaxBrightness() {
		provider.brightnessToReturn = 1.0

		let result = syncManager.sync(gamma: 2.2)

		XCTAssertTrue(result)
		XCTAssertEqual(controller.lastSetBrightness, 1.0)
	}

	// MARK: - Threshold Tests

	func testSyncDoesNotUpdateForSmallChanges() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 1.0)

		// Change less than threshold (0.005)
		provider.brightnessToReturn = 0.503
		_ = syncManager.sync(gamma: 1.0)

		// Should only call controller once
		XCTAssertEqual(controller.callCount, 1)
	}

	func testSyncUpdatesForLargeChanges() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 1.0)

		// Change more than threshold (0.005)
		provider.brightnessToReturn = 0.51
		_ = syncManager.sync(gamma: 1.0)

		// Should call controller twice
		XCTAssertEqual(controller.callCount, 2)
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.51, accuracy: 0.001)
	}

	// MARK: - Error Handling Tests

	func testSyncFailsWhenProviderReturnsNil() {
		provider.brightnessToReturn = nil

		let result = syncManager.sync(gamma: 1.0)

		XCTAssertFalse(result)
		XCTAssertEqual(controller.callCount, 0)
	}

	func testSyncReturnsControllerResult() {
		provider.brightnessToReturn = 0.5
		controller.shouldSucceed = false

		let result = syncManager.sync(gamma: 1.0)

		XCTAssertFalse(result)
	}

	func testSyncSucceedsWhenNoChangeNeeded() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 1.0)

		// Same brightness, no change needed
		let result = syncManager.sync(gamma: 1.0)

		XCTAssertTrue(result) // Should return true even though no update was made
		XCTAssertEqual(controller.callCount, 1) // Controller only called once
	}

	// MARK: - Reset Tests

	func testResetForcesNextSync() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 1.0)

		syncManager.reset()

		// Same brightness, but should sync due to reset
		_ = syncManager.sync(gamma: 1.0)

		XCTAssertEqual(controller.callCount, 2)
	}

	// MARK: - LastSyncedBrightness Tests

	func testLastSyncedBrightnessInitialValue() {
		XCTAssertEqual(syncManager.lastSyncedBrightness, -1)
	}

	func testLastSyncedBrightnessAfterSync() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 2.0)

		XCTAssertEqual(Double(syncManager.lastSyncedBrightness), 0.25, accuracy: 0.001)
	}

	func testLastSyncedBrightnessAfterReset() {
		provider.brightnessToReturn = 0.5
		_ = syncManager.sync(gamma: 1.0)

		syncManager.reset()

		XCTAssertEqual(syncManager.lastSyncedBrightness, -1)
	}

	// MARK: - Gamma Edge Cases

	func testSyncWithLowBrightnessAndHighGamma() {
		provider.brightnessToReturn = 0.1

		_ = syncManager.sync(gamma: 2.2)

		// 0.1^2.2 ≈ 0.0063
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.0063, accuracy: 0.001)
	}

	func testSyncWithMultipleGammaValues() {
		provider.brightnessToReturn = 0.5

		_ = syncManager.sync(gamma: 1.0)
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.5, accuracy: 0.001)

		provider.brightnessToReturn = 0.6
		_ = syncManager.sync(gamma: 1.5)
		// 0.6^1.5 ≈ 0.4648
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.4648, accuracy: 0.001)

		provider.brightnessToReturn = 0.7
		_ = syncManager.sync(gamma: 2.2)
		// 0.7^2.2 ≈ 0.4563
		XCTAssertNotNil(controller.lastSetBrightness)
		XCTAssertEqual(controller.lastSetBrightness!, 0.4563, accuracy: 0.001)
	}

	// MARK: - Full Range Tests

	func testSyncAcrossFullBrightnessRange() {
		let testValues: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
		let gamma = 1.5

		for value in testValues {
			provider.brightnessToReturn = value
			let result = syncManager.sync(gamma: gamma)

			XCTAssertTrue(result)
			let expected = Float(pow(Double(value), gamma))
			XCTAssertNotNil(controller.lastSetBrightness)
			XCTAssertEqual(controller.lastSetBrightness!, expected, accuracy: 0.001)
		}
	}
}
