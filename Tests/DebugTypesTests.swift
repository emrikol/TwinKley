@testable import TwinKleyCore
import XCTest

final class EventTapHealthTests: XCTestCase {
	func testDefaultInit() {
		let health = EventTapHealth()

		XCTAssertFalse(health.isRunning)
		XCTAssertEqual(health.eventsReceived, 0)
		XCTAssertEqual(health.brightnessEventsReceived, 0)
		XCTAssertEqual(health.disabledByTimeoutCount, 0)
		XCTAssertEqual(health.disabledByUserInputCount, 0)
		XCTAssertEqual(health.reenabledCount, 0)
		XCTAssertNil(health.lastEventTimestamp)
		XCTAssertNil(health.lastDisabledTimestamp)
		XCTAssertNil(health.createdTimestamp)
		XCTAssertTrue(health.keyCodeDistribution.isEmpty)
	}

	func testMutableProperties() {
		var health = EventTapHealth()

		health.isRunning = true
		health.eventsReceived = 10
		health.brightnessEventsReceived = 5
		health.disabledByTimeoutCount = 2
		health.disabledByUserInputCount = 1
		health.reenabledCount = 3

		let now = Date()
		health.lastEventTimestamp = now
		health.lastDisabledTimestamp = now
		health.createdTimestamp = now

		XCTAssertTrue(health.isRunning)
		XCTAssertEqual(health.eventsReceived, 10)
		XCTAssertEqual(health.brightnessEventsReceived, 5)
		XCTAssertEqual(health.disabledByTimeoutCount, 2)
		XCTAssertEqual(health.disabledByUserInputCount, 1)
		XCTAssertEqual(health.reenabledCount, 3)
		XCTAssertEqual(health.lastEventTimestamp, now)
		XCTAssertEqual(health.lastDisabledTimestamp, now)
		XCTAssertEqual(health.createdTimestamp, now)
	}

	func testTrackKeyCode() {
		var health = EventTapHealth()

		health.trackKeyCode(6)
		XCTAssertEqual(health.keyCodeDistribution[6], 1)

		health.trackKeyCode(6)
		XCTAssertEqual(health.keyCodeDistribution[6], 2)

		health.trackKeyCode(144)
		XCTAssertEqual(health.keyCodeDistribution[144], 1)
		XCTAssertEqual(health.keyCodeDistribution[6], 2)
	}

	func testTrackKeyCodeMultipleKeys() {
		var health = EventTapHealth()

		// Simulate various key codes being tracked
		let keyCodes = [6, 6, 6, 144, 145, 144, 2, 3]
		for code in keyCodes {
			health.trackKeyCode(code)
		}

		XCTAssertEqual(health.keyCodeDistribution[6], 3)
		XCTAssertEqual(health.keyCodeDistribution[144], 2)
		XCTAssertEqual(health.keyCodeDistribution[145], 1)
		XCTAssertEqual(health.keyCodeDistribution[2], 1)
		XCTAssertEqual(health.keyCodeDistribution[3], 1)
		XCTAssertEqual(health.keyCodeDistribution.count, 5)
	}
}

final class SyncRecordTests: XCTestCase {
	func testInitWithAllParameters() {
		let timestamp = Date()
		let record = SyncRecord(
			timestamp: timestamp,
			trigger: .keypress,
			displayBrightness: 0.75,
			keyboardBrightness: 0.5,
			gamma: 2.2,
			success: true,
			durationMs: 15,
			changeNeeded: true
		)

		XCTAssertEqual(record.timestamp, timestamp)
		XCTAssertEqual(record.trigger, .keypress)
		XCTAssertEqual(record.displayBrightness, 0.75, accuracy: 0.001)
		XCTAssertEqual(record.keyboardBrightness, 0.5, accuracy: 0.001)
		XCTAssertEqual(record.gamma, 2.2, accuracy: 0.001)
		XCTAssertTrue(record.success)
		XCTAssertEqual(record.durationMs, 15)
		XCTAssertTrue(record.changeNeeded)
	}

	func testInitWithDefaultTimestamp() {
		let before = Date()
		let record = SyncRecord(
			trigger: .timer,
			displayBrightness: 0.5,
			keyboardBrightness: 0.5,
			gamma: 1.0,
			success: true,
			durationMs: 10,
			changeNeeded: false
		)
		let after = Date()

		XCTAssertGreaterThanOrEqual(record.timestamp, before)
		XCTAssertLessThanOrEqual(record.timestamp, after)
	}

	func testFailedSyncRecord() {
		let record = SyncRecord(
			trigger: .manual,
			displayBrightness: 0.8,
			keyboardBrightness: 0.0,
			gamma: 2.0,
			success: false,
			durationMs: 5,
			changeNeeded: true
		)

		XCTAssertFalse(record.success)
		XCTAssertTrue(record.changeNeeded)
	}

	func testAllTriggerTypes() {
		let triggers: [SyncTrigger] = [.keypress, .timer, .wake, .displayChange, .manual, .startup]

		for trigger in triggers {
			let record = SyncRecord(
				trigger: trigger,
				displayBrightness: 0.5,
				keyboardBrightness: 0.5,
				gamma: 1.0,
				success: true,
				durationMs: 1,
				changeNeeded: false
			)
			XCTAssertEqual(record.trigger, trigger)
		}
	}
}

final class SyncTriggerTests: XCTestCase {
	func testRawValues() {
		XCTAssertEqual(SyncTrigger.keypress.rawValue, "keypress")
		XCTAssertEqual(SyncTrigger.timer.rawValue, "timer")
		XCTAssertEqual(SyncTrigger.wake.rawValue, "wake")
		XCTAssertEqual(SyncTrigger.displayChange.rawValue, "display")
		XCTAssertEqual(SyncTrigger.manual.rawValue, "manual")
		XCTAssertEqual(SyncTrigger.startup.rawValue, "startup")
	}

	func testInitFromRawValue() {
		XCTAssertEqual(SyncTrigger(rawValue: "keypress"), .keypress)
		XCTAssertEqual(SyncTrigger(rawValue: "timer"), .timer)
		XCTAssertEqual(SyncTrigger(rawValue: "wake"), .wake)
		XCTAssertEqual(SyncTrigger(rawValue: "display"), .displayChange)
		XCTAssertEqual(SyncTrigger(rawValue: "manual"), .manual)
		XCTAssertEqual(SyncTrigger(rawValue: "startup"), .startup)
	}

	func testInvalidRawValue() {
		XCTAssertNil(SyncTrigger(rawValue: "invalid"))
		XCTAssertNil(SyncTrigger(rawValue: ""))
		XCTAssertNil(SyncTrigger(rawValue: "KEYPRESS"))
	}
}
