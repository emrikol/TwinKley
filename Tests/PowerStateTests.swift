@testable import TwinKleyCore
import XCTest

// MARK: - Mock Providers

/// Mock provider that returns nil (simulates IOKit failure)
struct NilPowerSourceProvider: PowerSourceProvider {
	func getPowerSourcesInfo() -> [[String: Any]]? {
		nil
	}
}

/// Mock provider that returns configured power source data
struct MockPowerSourceProvider: PowerSourceProvider {
	let sources: [[String: Any]]?

	func getPowerSourcesInfo() -> [[String: Any]]? {
		sources
	}
}

// MARK: - PowerState Tests

final class PowerStateTests: XCTestCase {
	func testDefaultInit() {
		let state = PowerState()

		XCTAssertFalse(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, -1)
	}

	func testInitWithParameters() {
		let state = PowerState(isOnBattery: true, batteryLevel: 75)

		XCTAssertTrue(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, 75)
	}

	func testIsLowBatteryWhenBelow20() {
		let state = PowerState(isOnBattery: true, batteryLevel: 19)
		XCTAssertTrue(state.isLowBattery)
	}

	func testIsLowBatteryAt0Percent() {
		let state = PowerState(isOnBattery: true, batteryLevel: 0)
		XCTAssertTrue(state.isLowBattery)
	}

	func testIsNotLowBatteryAt20Percent() {
		let state = PowerState(isOnBattery: true, batteryLevel: 20)
		XCTAssertFalse(state.isLowBattery)
	}

	func testIsNotLowBatteryAbove20() {
		let state = PowerState(isOnBattery: true, batteryLevel: 50)
		XCTAssertFalse(state.isLowBattery)
	}

	func testIsNotLowBatteryAt100() {
		let state = PowerState(isOnBattery: false, batteryLevel: 100)
		XCTAssertFalse(state.isLowBattery)
	}

	func testIsNotLowBatteryWhenUnknown() {
		let state = PowerState(isOnBattery: true, batteryLevel: -1)
		XCTAssertFalse(state.isLowBattery, "Unknown battery level (-1) should not be considered low")
	}

	func testMutableProperties() {
		var state = PowerState()

		state.isOnBattery = true
		state.batteryLevel = 45

		XCTAssertTrue(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, 45)
	}

	func testLowBatteryBoundaryValues() {
		// Test exact boundary at 19 (low) and 20 (not low)
		let lowState = PowerState(isOnBattery: true, batteryLevel: 19)
		let normalState = PowerState(isOnBattery: true, batteryLevel: 20)

		XCTAssertTrue(lowState.isLowBattery)
		XCTAssertFalse(normalState.isLowBattery)
	}

	// MARK: - Static Constants

	func testPowerSourceKeys() {
		XCTAssertEqual(PowerState.powerSourceStateKey, "Power Source State")
		XCTAssertEqual(PowerState.currentCapacityKey, "Current Capacity")
		XCTAssertEqual(PowerState.batteryPowerValue, "Battery Power")
	}

	// MARK: - current() with Mock Providers

	func testCurrentWithNilProvider() {
		let provider = NilPowerSourceProvider()
		let state = PowerState.current(provider: provider)

		XCTAssertFalse(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, -1)
	}

	func testCurrentWithBatteryPower() {
		let sources: [[String: Any]] = [
			[
				PowerState.powerSourceStateKey: PowerState.batteryPowerValue,
				PowerState.currentCapacityKey: 45
			]
		]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertTrue(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, 45)
	}

	func testCurrentWithACPower() {
		let sources: [[String: Any]] = [
			[
				PowerState.powerSourceStateKey: "AC Power",
				PowerState.currentCapacityKey: 100
			]
		]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertFalse(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, 100)
	}

	func testCurrentWithMissingPowerSourceKey() {
		let sources: [[String: Any]] = [
			[
				PowerState.currentCapacityKey: 75
			]
		]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertFalse(state.isOnBattery, "Should default to false when key missing")
		XCTAssertEqual(state.batteryLevel, 75)
	}

	func testCurrentWithMissingCapacityKey() {
		let sources: [[String: Any]] = [
			[
				PowerState.powerSourceStateKey: PowerState.batteryPowerValue
			]
		]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertTrue(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, -1, "Should default to -1 when key missing")
	}

	func testCurrentWithEmptySourceInfo() {
		let sources: [[String: Any]] = [[:]]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertFalse(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, -1)
	}

	func testCurrentWithMultipleSources() {
		// Last source should win
		let sources: [[String: Any]] = [
			[
				PowerState.powerSourceStateKey: "AC Power",
				PowerState.currentCapacityKey: 50
			],
			[
				PowerState.powerSourceStateKey: PowerState.batteryPowerValue,
				PowerState.currentCapacityKey: 80
			]
		]
		let provider = MockPowerSourceProvider(sources: sources)
		let state = PowerState.current(provider: provider)

		XCTAssertTrue(state.isOnBattery)
		XCTAssertEqual(state.batteryLevel, 80)
	}
}
