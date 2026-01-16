@testable import TwinKleyCore
import XCTest

final class SettingsTests: XCTestCase {
	// MARK: - Settings Struct Tests

	func testDefaultSettings() {
		let settings = Settings.default

		XCTAssertTrue(settings.liveSyncEnabled)
		XCTAssertTrue(settings.timedSyncEnabled)
		XCTAssertEqual(settings.timedSyncIntervalMs, 10_000)
		XCTAssertFalse(settings.pauseTimedSyncOnBattery)
		XCTAssertTrue(settings.pauseTimedSyncOnLowBattery)
		XCTAssertEqual(settings.brightnessGamma, 1.5)
	}

	func testIntervalClamping() {
		// Test below minimum
		XCTAssertEqual(Settings.clampInterval(50), Settings.intervalMin)
		XCTAssertEqual(Settings.clampInterval(0), Settings.intervalMin)
		XCTAssertEqual(Settings.clampInterval(-100), Settings.intervalMin)

		// Test above maximum
		XCTAssertEqual(Settings.clampInterval(70_000), Settings.intervalMax)
		XCTAssertEqual(Settings.clampInterval(100_000), Settings.intervalMax)

		// Test within range
		XCTAssertEqual(Settings.clampInterval(500), 500)
		XCTAssertEqual(Settings.clampInterval(1_000), 1_000)
		XCTAssertEqual(Settings.clampInterval(30_000), 30_000)

		// Test boundaries
		XCTAssertEqual(Settings.clampInterval(100), 100)
		XCTAssertEqual(Settings.clampInterval(60_000), 60_000)
	}

	func testIntervalClampingOnInit() {
		// Interval should be clamped during initialization
		let settingsLow = Settings(timedSyncIntervalMs: 10)
		XCTAssertEqual(settingsLow.timedSyncIntervalMs, Settings.intervalMin)

		let settingsHigh = Settings(timedSyncIntervalMs: 100_000)
		XCTAssertEqual(settingsHigh.timedSyncIntervalMs, Settings.intervalMax)

		let settingsValid = Settings(timedSyncIntervalMs: 30_000)
		XCTAssertEqual(settingsValid.timedSyncIntervalMs, 30_000)
	}

	func testIntervalSecondsConversion() {
		let settings1 = Settings(timedSyncIntervalMs: 1_000)
		XCTAssertEqual(settings1.timedSyncIntervalSeconds, 1.0, accuracy: 0.001)

		let settings2 = Settings(timedSyncIntervalMs: 500)
		XCTAssertEqual(settings2.timedSyncIntervalSeconds, 0.5, accuracy: 0.001)

		let settings3 = Settings(timedSyncIntervalMs: 2_500)
		XCTAssertEqual(settings3.timedSyncIntervalSeconds, 2.5, accuracy: 0.001)
	}

	func testSettingsEquality() {
		let settings1 = Settings(
			liveSyncEnabled: true,
			timedSyncEnabled: false,
			timedSyncIntervalMs: 500
		)
		let settings2 = Settings(
			liveSyncEnabled: true,
			timedSyncEnabled: false,
			timedSyncIntervalMs: 500
		)
		let settings3 = Settings(
			liveSyncEnabled: false,
			timedSyncEnabled: false,
			timedSyncIntervalMs: 500
		)

		XCTAssertEqual(settings1, settings2)
		XCTAssertNotEqual(settings1, settings3)
	}

	// MARK: - Settings Manager Tests

	func testSettingsManagerLoadDefault() {
		// Use a temp file that doesn't exist
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		let manager = SettingsManager(fileURL: tempURL)

		// Should load defaults when file doesn't exist
		XCTAssertEqual(manager.settings, Settings.default)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsManagerDefaultFileURL() {
		// Test that defaultFileURL returns the expected path
		let url = SettingsManager.defaultFileURL
		XCTAssertTrue(url.path.contains(".twinkley.json"))
		XCTAssertTrue(url.path.hasPrefix("/Users/"))
	}

	func testSettingsManagerUsesDefaultURLWhenNil() {
		// Test that passing nil uses the default file URL
		// This exercises the nil-coalescing branch in init
		let manager = SettingsManager(fileURL: nil)
		// Just verify it initializes without crashing and has default settings
		XCTAssertEqual(manager.settings.liveSyncEnabled, Settings.default.liveSyncEnabled)
	}

	func testSettingsManagerSaveFailure() {
		// Use an invalid path that will fail to write
		let invalidURL = URL(fileURLWithPath: "/nonexistent/directory/settings.json")

		let manager = SettingsManager(fileURL: invalidURL)
		let result = manager.save()

		// Save should fail and return false
		XCTAssertFalse(result)
	}

	func testSettingsManagerSaveAndLoad() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		// Create manager and modify settings
		let manager1 = SettingsManager(fileURL: tempURL)
		manager1.update {
			$0.liveSyncEnabled = false
			$0.timedSyncEnabled = false
			$0.timedSyncIntervalMs = 2_000
		}

		// Create new manager to load saved settings
		let manager2 = SettingsManager(fileURL: tempURL)

		XCTAssertFalse(manager2.settings.liveSyncEnabled)
		XCTAssertFalse(manager2.settings.timedSyncEnabled)
		XCTAssertEqual(manager2.settings.timedSyncIntervalMs, 2_000)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsManagerUpdate() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		let manager = SettingsManager(fileURL: tempURL)

		XCTAssertTrue(manager.settings.liveSyncEnabled)

		manager.update { $0.liveSyncEnabled = false }

		XCTAssertFalse(manager.settings.liveSyncEnabled)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsManagerToggle() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		let manager = SettingsManager(fileURL: tempURL)

		let initialValue = manager.settings.timedSyncEnabled
		manager.update { $0.timedSyncEnabled.toggle() }

		XCTAssertNotEqual(manager.settings.timedSyncEnabled, initialValue)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	// MARK: - JSON Encoding/Decoding Tests

	func testSettingsCodable() throws {
		let original = Settings(
			liveSyncEnabled: false,
			timedSyncEnabled: true,
			timedSyncIntervalMs: 3_000
		)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(Settings.self, from: data)

		XCTAssertEqual(original, decoded)
	}

	func testSettingsJSONFormat() throws {
		let settings = Settings(
			liveSyncEnabled: true,
			timedSyncEnabled: false,
			timedSyncIntervalMs: 1_500
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let data = try encoder.encode(settings)
		let jsonString = String(data: data, encoding: .utf8)!

		XCTAssertTrue(jsonString.contains("\"liveSyncEnabled\" : true"))
		XCTAssertTrue(jsonString.contains("\"timedSyncEnabled\" : false"))
		XCTAssertTrue(jsonString.contains("\"timedSyncIntervalMs\" : 1500"))
	}

	// MARK: - Battery Settings Tests

	func testBatterySettings() {
		// Test default battery settings
		let defaultSettings = Settings.default
		XCTAssertFalse(defaultSettings.pauseTimedSyncOnBattery)
		XCTAssertTrue(defaultSettings.pauseTimedSyncOnLowBattery)

		// Test custom battery settings
		let customSettings = Settings(
			pauseTimedSyncOnBattery: true,
			pauseTimedSyncOnLowBattery: false
		)
		XCTAssertTrue(customSettings.pauseTimedSyncOnBattery)
		XCTAssertFalse(customSettings.pauseTimedSyncOnLowBattery)
	}

	func testBatterySettingsPersistence() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		// Create manager and modify battery settings
		let manager1 = SettingsManager(fileURL: tempURL)
		manager1.update {
			$0.pauseTimedSyncOnBattery = true
			$0.pauseTimedSyncOnLowBattery = false
		}

		// Create new manager to load saved settings
		let manager2 = SettingsManager(fileURL: tempURL)

		XCTAssertTrue(manager2.settings.pauseTimedSyncOnBattery)
		XCTAssertFalse(manager2.settings.pauseTimedSyncOnLowBattery)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	// MARK: - Constants Tests

	func testIntervalConstants() {
		XCTAssertEqual(Settings.intervalMin, 100)
		XCTAssertEqual(Settings.intervalMax, 60_000)
		XCTAssertEqual(Settings.intervalDefault, 10_000)

		// Default should be within range
		XCTAssertGreaterThanOrEqual(Settings.intervalDefault, Settings.intervalMin)
		XCTAssertLessThanOrEqual(Settings.intervalDefault, Settings.intervalMax)
	}

	// MARK: - Gamma Correction Tests

	func testGammaClamping() {
		// Test below minimum
		XCTAssertEqual(Settings.clampGamma(0.1), Settings.gammaMin)
		XCTAssertEqual(Settings.clampGamma(0.0), Settings.gammaMin)
		XCTAssertEqual(Settings.clampGamma(-1.0), Settings.gammaMin)

		// Test above maximum
		XCTAssertEqual(Settings.clampGamma(5.0), Settings.gammaMax)
		XCTAssertEqual(Settings.clampGamma(10.0), Settings.gammaMax)

		// Test within range
		XCTAssertEqual(Settings.clampGamma(1.0), 1.0)
		XCTAssertEqual(Settings.clampGamma(2.2), 2.2)
		XCTAssertEqual(Settings.clampGamma(3.0), 3.0)

		// Test boundaries
		XCTAssertEqual(Settings.clampGamma(0.5), 0.5)
		XCTAssertEqual(Settings.clampGamma(4.0), 4.0)
	}

	func testGammaClampingOnInit() {
		// Gamma should be clamped during initialization
		let settingsLow = Settings(brightnessGamma: 0.1)
		XCTAssertEqual(settingsLow.brightnessGamma, Settings.gammaMin)

		let settingsHigh = Settings(brightnessGamma: 10.0)
		XCTAssertEqual(settingsHigh.brightnessGamma, Settings.gammaMax)

		let settingsValid = Settings(brightnessGamma: 2.2)
		XCTAssertEqual(settingsValid.brightnessGamma, 2.2)
	}

	func testGammaConstants() {
		XCTAssertEqual(Settings.gammaMin, 0.5)
		XCTAssertEqual(Settings.gammaMax, 4.0)
		XCTAssertEqual(Settings.gammaDefault, 1.5)

		// Default should be within range
		XCTAssertGreaterThanOrEqual(Settings.gammaDefault, Settings.gammaMin)
		XCTAssertLessThanOrEqual(Settings.gammaDefault, Settings.gammaMax)
	}

	func testGammaPersistence() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		// Create manager and modify gamma setting
		let manager1 = SettingsManager(fileURL: tempURL)
		manager1.update { $0.brightnessGamma = 2.2 }

		// Create new manager to load saved settings
		let manager2 = SettingsManager(fileURL: tempURL)
		XCTAssertEqual(manager2.settings.brightnessGamma, 2.2, accuracy: 0.001)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	// MARK: - Backward Compatibility Tests

	func testBackwardCompatibilityKeypressSyncEnabled() throws {
		// Test that old settings files with "keypressSyncEnabled" still load correctly
		let oldJSON = """
		{
			"keypressSyncEnabled": false,
			"timedSyncEnabled": true,
			"timedSyncIntervalMs": 5000,
			"pauseTimedSyncOnBattery": true,
			"pauseTimedSyncOnLowBattery": false,
			"brightnessGamma": 2.0
		}
		"""

		let data = oldJSON.data(using: .utf8)!
		let decoder = JSONDecoder()
		let settings = try decoder.decode(Settings.self, from: data)

		// Should migrate old keypressSyncEnabled to liveSyncEnabled
		XCTAssertFalse(settings.liveSyncEnabled)
		XCTAssertTrue(settings.timedSyncEnabled)
		XCTAssertEqual(settings.timedSyncIntervalMs, 5000)
		XCTAssertTrue(settings.pauseTimedSyncOnBattery)
		XCTAssertFalse(settings.pauseTimedSyncOnLowBattery)
		XCTAssertEqual(settings.brightnessGamma, 2.0, accuracy: 0.001)
	}

	func testNewJSONFormat() throws {
		// Test that new settings save with the correct key name
		let settings = Settings(
			liveSyncEnabled: true,
			timedSyncEnabled: false,
			timedSyncIntervalMs: 1_500
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let data = try encoder.encode(settings)
		let jsonString = String(data: data, encoding: .utf8)!

		// Should save with new key name
		XCTAssertTrue(jsonString.contains("\"liveSyncEnabled\" : true"))
		// Should NOT save old key name
		XCTAssertFalse(jsonString.contains("\"keypressSyncEnabled\""))
	}
}
