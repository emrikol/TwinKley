@testable import TwinKleyCore
import XCTest

final class SettingsTests: XCTestCase {
	// MARK: - Settings Struct Tests

	func testDefaultSettings() {
		let settings = Settings.default

		XCTAssertTrue(settings.liveSyncEnabled)
		XCTAssertFalse(settings.timedSyncEnabled) // Off by default for energy efficiency
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

	// MARK: - Settings Loader Tests

	func testSettingsLoaderLoadDefault() {
		// Use a temp file that doesn't exist
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		let settings = SettingsLoader.load(from: tempURL)

		// Should load defaults when file doesn't exist
		XCTAssertEqual(settings, Settings.default)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsLoaderDefaultFileURL() {
		// Test that defaultFileURL returns the expected path
		let url = SettingsLoader.defaultFileURL
		XCTAssertTrue(url.path.contains(".twinkley.json"))
		XCTAssertTrue(url.path.hasPrefix("/Users/"))
	}

	func testSettingsLoaderUsesDefaultURLWhenNil() {
		// Test that passing nil uses the default file URL
		let settings = SettingsLoader.load(from: nil)
		// Just verify it loads without crashing
		XCTAssertNotNil(settings)
	}

	func testSettingsLoaderSaveUsesDefaultURLWhenNil() {
		// Test that save() with no URL argument uses the default file URL
		let defaultURL = SettingsLoader.defaultFileURL
		let backupURL = defaultURL.deletingLastPathComponent()
			.appendingPathComponent(".twinkley-backup-\(UUID().uuidString).json")

		// Backup existing settings if present
		let hasExisting = FileManager.default.fileExists(atPath: defaultURL.path)
		if hasExisting {
			try? FileManager.default.moveItem(at: defaultURL, to: backupURL)
		}

		defer {
			// Cleanup and restore
			try? FileManager.default.removeItem(at: defaultURL)
			if hasExisting {
				try? FileManager.default.moveItem(at: backupURL, to: defaultURL)
			}
		}

		// Save using default URL (nil parameter)
		let settings = Settings(liveSyncEnabled: false, timedSyncEnabled: true, timedSyncIntervalMs: 999)
		let result = SettingsLoader.save(settings, to: nil)

		XCTAssertTrue(result, "Save should succeed")
		XCTAssertTrue(FileManager.default.fileExists(atPath: defaultURL.path), "File should exist at default URL")

		// Verify we can load it back
		let loaded = SettingsLoader.load(from: defaultURL)
		XCTAssertEqual(loaded.timedSyncIntervalMs, 999)
	}

	func testSettingsLoaderSaveFailure() {
		// Use an invalid path that will fail to write
		let invalidURL = URL(fileURLWithPath: "/nonexistent/directory/settings.json")

		let settings = Settings.default
		let result = SettingsLoader.save(settings, to: invalidURL)

		// Save should fail and return false
		XCTAssertFalse(result)
	}

	func testSettingsLoaderSaveAndLoad() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		// Create and modify settings
		var settings = Settings.default
		settings.liveSyncEnabled = false
		settings.timedSyncEnabled = false
		settings.timedSyncIntervalMs = 2_000

		// Save settings
		let saveResult = SettingsLoader.save(settings, to: tempURL)
		XCTAssertTrue(saveResult)

		// Load saved settings
		let loadedSettings = SettingsLoader.load(from: tempURL)

		XCTAssertFalse(loadedSettings.liveSyncEnabled)
		XCTAssertFalse(loadedSettings.timedSyncEnabled)
		XCTAssertEqual(loadedSettings.timedSyncIntervalMs, 2_000)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsLoaderUpdate() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		var settings = Settings.default
		XCTAssertTrue(settings.liveSyncEnabled)

		settings.liveSyncEnabled = false
		SettingsLoader.save(settings, to: tempURL)

		let loadedSettings = SettingsLoader.load(from: tempURL)
		XCTAssertFalse(loadedSettings.liveSyncEnabled)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	func testSettingsLoaderToggle() {
		let tempURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".json")

		var settings = Settings.default
		let initialValue = settings.timedSyncEnabled
		settings.timedSyncEnabled.toggle()
		SettingsLoader.save(settings, to: tempURL)

		let loadedSettings = SettingsLoader.load(from: tempURL)
		XCTAssertNotEqual(loadedSettings.timedSyncEnabled, initialValue)

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

		// Create and modify battery settings
		var settings = Settings.default
		settings.pauseTimedSyncOnBattery = true
		settings.pauseTimedSyncOnLowBattery = false
		SettingsLoader.save(settings, to: tempURL)

		// Load saved settings
		let loadedSettings = SettingsLoader.load(from: tempURL)

		XCTAssertTrue(loadedSettings.pauseTimedSyncOnBattery)
		XCTAssertFalse(loadedSettings.pauseTimedSyncOnLowBattery)

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

		// Create and modify gamma setting
		var settings = Settings.default
		settings.brightnessGamma = 2.2
		SettingsLoader.save(settings, to: tempURL)

		// Load saved settings
		let loadedSettings = SettingsLoader.load(from: tempURL)
		XCTAssertEqual(loadedSettings.brightnessGamma, 2.2, accuracy: 0.001)

		// Cleanup
		try? FileManager.default.removeItem(at: tempURL)
	}

	// MARK: - JSON Key Names Tests

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

	// MARK: - Decode Clamping Tests (Security)

	func testDecodingInvalidIntervalBelowMinClamps() throws {
		// JSON with interval below minimum should be clamped on decode
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": false,
			"timedSyncIntervalMs": 50,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 1.5,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to minimum (100ms)
		XCTAssertEqual(decoded.timedSyncIntervalMs, Settings.intervalMin)
	}

	func testDecodingInvalidIntervalAboveMaxClamps() throws {
		// JSON with interval above maximum should be clamped on decode
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": false,
			"timedSyncIntervalMs": 100000,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 1.5,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to maximum (60000ms)
		XCTAssertEqual(decoded.timedSyncIntervalMs, Settings.intervalMax)
	}

	func testDecodingNegativeIntervalClamps() throws {
		// JSON with negative interval should be clamped on decode
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": false,
			"timedSyncIntervalMs": -100,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 1.5,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to minimum (100ms)
		XCTAssertEqual(decoded.timedSyncIntervalMs, Settings.intervalMin)
	}

	func testDecodingInvalidGammaBelowMinClamps() throws {
		// JSON with gamma below minimum should be clamped on decode
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": false,
			"timedSyncIntervalMs": 10000,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 0.1,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to minimum (0.5)
		XCTAssertEqual(decoded.brightnessGamma, Settings.gammaMin)
	}

	func testDecodingInvalidGammaAboveMaxClamps() throws {
		// JSON with gamma above maximum should be clamped on decode
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": false,
			"timedSyncIntervalMs": 10000,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 10.0,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to maximum (4.0)
		XCTAssertEqual(decoded.brightnessGamma, Settings.gammaMax)
	}

	func testDecodingZeroIntervalClamps() throws {
		// JSON with zero interval (would cause CPU spin) should be clamped
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncEnabled": true,
			"timedSyncIntervalMs": 0,
			"pauseTimedSyncOnBattery": false,
			"pauseTimedSyncOnLowBattery": true,
			"brightnessGamma": 1.5,
			"hasLaunchedBefore": false,
			"hasAcknowledgedUpdatePrivacy": false
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)

		// Should be clamped to minimum (100ms) - prevents CPU spin
		XCTAssertEqual(decoded.timedSyncIntervalMs, Settings.intervalMin)
	}

	// MARK: - Backward Compatibility Tests

	func testDecodingWithMissingKeysUsesDefaults() throws {
		// Minimal JSON (old version) should decode without throwing and use defaults
		let json = """
		{
			"liveSyncEnabled": true,
			"timedSyncIntervalMs": 5000
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)
		let defaults = Settings()

		// Specified values should be used
		XCTAssertEqual(decoded.liveSyncEnabled, true)
		XCTAssertEqual(decoded.timedSyncIntervalMs, 5_000)

		// Missing keys should use defaults
		XCTAssertEqual(decoded.timedSyncEnabled, defaults.timedSyncEnabled)
		XCTAssertEqual(decoded.pauseTimedSyncOnBattery, defaults.pauseTimedSyncOnBattery)
		XCTAssertEqual(decoded.pauseTimedSyncOnLowBattery, defaults.pauseTimedSyncOnLowBattery)
		XCTAssertEqual(decoded.brightnessGamma, defaults.brightnessGamma)
		XCTAssertEqual(decoded.hasLaunchedBefore, defaults.hasLaunchedBefore)
		XCTAssertEqual(decoded.hasAcknowledgedUpdatePrivacy, defaults.hasAcknowledgedUpdatePrivacy)
	}

	func testDecodingEmptyJSONUsesAllDefaults() throws {
		// Empty JSON should decode successfully with all defaults
		let json = "{}"
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)
		let defaults = Settings()

		// All values should match defaults
		XCTAssertEqual(decoded.liveSyncEnabled, defaults.liveSyncEnabled)
		XCTAssertEqual(decoded.timedSyncEnabled, defaults.timedSyncEnabled)
		XCTAssertEqual(decoded.timedSyncIntervalMs, defaults.timedSyncIntervalMs)
		XCTAssertEqual(decoded.pauseTimedSyncOnBattery, defaults.pauseTimedSyncOnBattery)
		XCTAssertEqual(decoded.pauseTimedSyncOnLowBattery, defaults.pauseTimedSyncOnLowBattery)
		XCTAssertEqual(decoded.brightnessGamma, defaults.brightnessGamma)
		XCTAssertEqual(decoded.hasLaunchedBefore, defaults.hasLaunchedBefore)
		XCTAssertEqual(decoded.hasAcknowledgedUpdatePrivacy, defaults.hasAcknowledgedUpdatePrivacy)
	}

	func testDecodingPartialJSONWithInvalidValuesClampsAndFillsDefaults() throws {
		// Partial JSON with some invalid values - should clamp invalids and use defaults for missing
		let json = """
		{
			"timedSyncIntervalMs": -500,
			"brightnessGamma": 10.0
		}
		"""
		let data = json.data(using: .utf8)!
		let decoded = try JSONDecoder().decode(Settings.self, from: data)
		let defaults = Settings()

		// Invalid values should be clamped
		XCTAssertEqual(decoded.timedSyncIntervalMs, Settings.intervalMin) // -500 → 100
		XCTAssertEqual(decoded.brightnessGamma, Settings.gammaMax) // 10.0 → 4.0

		// Missing keys should use defaults
		XCTAssertEqual(decoded.liveSyncEnabled, defaults.liveSyncEnabled)
		XCTAssertEqual(decoded.timedSyncEnabled, defaults.timedSyncEnabled)
	}
}
