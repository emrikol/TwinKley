import Foundation

// MARK: - App Info

/// App version information
public enum AppInfo {
	/// Display version string (e.g., "1.0.0-beta2", "1.0.0", "1.1.0")
	public static let version = "1.0.0-beta10"
	/// Build number for Sparkle (auto-incremented by build script)
	/// Combined with version base for CFBundleVersion (e.g., "1.0.0.2")
	/// This number always increments regardless of version changes
	public static let buildNumber = 43
	/// Full app name with emojis for display
	public static let name = "☀️ TwinK[l]ey ⌨️"
	/// Short app name for menus
	public static let shortName = "TwinK[l]ey"
	/// Bundle identifier
	public static let identifier = "com.emrikol.TwinKley"
	/// GitHub repository URL
	public static let githubURL = "https://github.com/emrikol/TwinKley"
}

// MARK: - Settings

/// App settings that can be persisted to disk
public struct Settings: Codable, Equatable {
	/// Event-driven sync (brightness keys, Control Center, etc.)
	public var liveSyncEnabled: Bool
	/// Background polling fallback
	public var timedSyncEnabled: Bool
	/// Polling interval in milliseconds
	public var timedSyncIntervalMs: Int
	/// Pause polling when on battery
	public var pauseTimedSyncOnBattery: Bool
	/// Pause polling when battery < 20%
	public var pauseTimedSyncOnLowBattery: Bool
	/// Gamma curve for perceptual brightness matching
	public var brightnessGamma: Double
	/// First-run tracking
	public var hasLaunchedBefore: Bool
	/// User acknowledged GitHub privacy notice
	public var hasAcknowledgedUpdatePrivacy: Bool
	/// NX_SYSDEFINED keyCodes to treat as brightness events
	public var brightnessKeyCodes: [Int]

	/// Minimum allowed polling interval (ms)
	public static let intervalMin = 100
	/// Maximum allowed polling interval (ms) - up to 1 minute
	public static let intervalMax = 60_000
	/// Default polling interval (ms) - 10 seconds
	public static let intervalDefault = 10_000

	/// Minimum allowed gamma value
	public static let gammaMin = 0.5
	/// Maximum allowed gamma value
	public static let gammaMax = 4.0
	/// Default gamma value - 1.5 = mild correction (recommended)
	public static let gammaDefault = 1.5
	/// Default brightness keyCodes - NX_KEYTYPE_BRIGHTNESS_UP (2) and NX_KEYTYPE_BRIGHTNESS_DOWN (3)
	/// Note: CGEvent field access gives incorrect results - must convert to NSEvent first
	public static let brightnessKeyCodesDefault = [2, 3]

	/// Default settings
	public static let `default` = Settings(
		liveSyncEnabled: true,
		timedSyncEnabled: false, // Off by default - live sync is event-driven (zero polling)
		timedSyncIntervalMs: intervalDefault,
		pauseTimedSyncOnBattery: false,
		pauseTimedSyncOnLowBattery: true,
		brightnessGamma: gammaDefault,
		hasLaunchedBefore: false,
		hasAcknowledgedUpdatePrivacy: false,
		brightnessKeyCodes: brightnessKeyCodesDefault
	)

	/// Creates settings with the given values
	/// - Parameters:
	///   - liveSyncEnabled: Enable event-driven sync (default: true)
	///   - timedSyncEnabled: Enable polling fallback (default: false)
	///   - timedSyncIntervalMs: Polling interval in ms (default: 10000)
	///   - pauseTimedSyncOnBattery: Pause on battery (default: false)
	///   - pauseTimedSyncOnLowBattery: Pause on low battery (default: true)
	///   - brightnessGamma: Gamma correction (default: 1.5)
	///   - hasLaunchedBefore: First run tracking (default: false)
	///   - hasAcknowledgedUpdatePrivacy: Privacy acknowledged (default: false)
	///   - brightnessKeyCodes: NX keyCodes to treat as brightness events
	public init(
		liveSyncEnabled: Bool = true,
		timedSyncEnabled: Bool = false,
		timedSyncIntervalMs: Int = intervalDefault,
		pauseTimedSyncOnBattery: Bool = false,
		pauseTimedSyncOnLowBattery: Bool = true,
		brightnessGamma: Double = gammaDefault,
		hasLaunchedBefore: Bool = false,
		hasAcknowledgedUpdatePrivacy: Bool = false,
		brightnessKeyCodes: [Int] = brightnessKeyCodesDefault
	) {
		self.liveSyncEnabled = liveSyncEnabled
		self.timedSyncEnabled = timedSyncEnabled
		self.timedSyncIntervalMs = Self.clampInterval(timedSyncIntervalMs)
		self.pauseTimedSyncOnBattery = pauseTimedSyncOnBattery
		self.pauseTimedSyncOnLowBattery = pauseTimedSyncOnLowBattery
		self.brightnessGamma = Self.clampGamma(brightnessGamma)
		self.hasLaunchedBefore = hasLaunchedBefore
		self.hasAcknowledgedUpdatePrivacy = hasAcknowledgedUpdatePrivacy
		self.brightnessKeyCodes = brightnessKeyCodes
	}

	// MARK: - Custom Codable (clamp values on decode)

	private enum CodingKeys: String, CodingKey {
		case liveSyncEnabled
		case timedSyncEnabled
		case timedSyncIntervalMs
		case pauseTimedSyncOnBattery
		case pauseTimedSyncOnLowBattery
		case brightnessGamma
		case hasLaunchedBefore
		case hasAcknowledgedUpdatePrivacy
		case brightnessKeyCodes
	}

	/// Custom decoder that clamps values to valid ranges
	/// - Important: Uses decodeIfPresent for backward compatibility with older configs
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = Settings()

		// Use decodeIfPresent to handle missing keys gracefully
		liveSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveSyncEnabled) ?? defaults.liveSyncEnabled
		timedSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .timedSyncEnabled) ?? defaults.timedSyncEnabled

		// Decode and clamp numeric values
		let rawInterval = try container.decodeIfPresent(Int.self, forKey: .timedSyncIntervalMs) ?? defaults.timedSyncIntervalMs
		timedSyncIntervalMs = Self.clampInterval(rawInterval)

		pauseTimedSyncOnBattery = try container.decodeIfPresent(Bool.self, forKey: .pauseTimedSyncOnBattery) ?? defaults.pauseTimedSyncOnBattery
		pauseTimedSyncOnLowBattery = try container.decodeIfPresent(Bool.self, forKey: .pauseTimedSyncOnLowBattery) ?? defaults.pauseTimedSyncOnLowBattery

		let rawGamma = try container.decodeIfPresent(Double.self, forKey: .brightnessGamma) ?? defaults.brightnessGamma
		brightnessGamma = Self.clampGamma(rawGamma)

		hasLaunchedBefore = try container.decodeIfPresent(Bool.self, forKey: .hasLaunchedBefore) ?? defaults.hasLaunchedBefore
		hasAcknowledgedUpdatePrivacy = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedUpdatePrivacy) ?? defaults.hasAcknowledgedUpdatePrivacy
		brightnessKeyCodes = try container.decodeIfPresent([Int].self, forKey: .brightnessKeyCodes) ?? defaults.brightnessKeyCodes
	}

	/// Clamp interval to valid range
	/// - Parameter value: Interval in milliseconds
	/// - Returns: Clamped value within [intervalMin, intervalMax]
	public static func clampInterval(_ value: Int) -> Int {
		min(max(value, intervalMin), intervalMax)
	}

	/// Clamp gamma to valid range
	/// - Parameter value: Gamma value
	/// - Returns: Clamped value within [gammaMin, gammaMax]
	public static func clampGamma(_ value: Double) -> Double {
		min(max(value, gammaMin), gammaMax)
	}

	/// Timer interval in seconds
	public var timedSyncIntervalSeconds: Double {
		Double(timedSyncIntervalMs) / 1_000.0
	}
}

// SettingsManager moved to TwinKleyUI for lazy loading

/// Minimal settings loader for main binary (minimal code, kept in Core for fast startup)
public enum SettingsLoader {
	/// Default settings file path (~/.twinkley.json)
	public static var defaultFileURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".twinkley.json")
	}

	/// Quick load settings from disk (returns default on error)
	/// - Parameter url: File URL to load from (default: ~/.twinkley.json)
	/// - Returns: Loaded settings or default if file doesn't exist/is invalid
	public static func load(from url: URL? = nil) -> Settings {
		let fileURL = url ?? defaultFileURL
		guard let data = try? Data(contentsOf: fileURL),
			  let decoded = try? JSONDecoder().decode(Settings.self, from: data) else
		{
			return Settings.default
		}
		return decoded
	}

	/// Quick save settings to disk
	/// - Parameters:
	///   - settings: Settings to save
	///   - url: File URL to save to (default: ~/.twinkley.json)
	/// - Returns: true if save succeeded
	@discardableResult
	public static func save(_ settings: Settings, to url: URL? = nil) -> Bool {
		let fileURL = url ?? defaultFileURL
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		guard let data = try? encoder.encode(settings) else { return false }
		// Use atomic write to prevent corruption if interrupted
		return (try? data.write(to: fileURL, options: .atomic)) != nil
	}
}
